# Run with: PORT=3128 bin/rails runner script/verify_local_inbox.rb
# Exercises the running HTTP app, including Rails sessions and CSRF protection.
abort "Development only" unless Rails.env.development?
require "net/http"
require "nokogiri"
require "cloudflare/email/verification"

base = URI("http://127.0.0.1:#{Integer(ENV.fetch('PORT', '3000'))}")
cookies = {}
request = lambda do |path, fields = nil, headers = {}, raw = nil|
  uri = base + path
  req = (fields || raw) ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req["Cookie"] = cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
  headers.each { |name, value| req[name] = value }
  req.set_form_data(fields) if fields
  req.body = raw if raw
  response = Net::HTTP.start(uri.host, uri.port, nil, nil, nil, nil, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
  Array(response.get_fields("set-cookie")).each do |cookie|
    name, value = cookie.split(";", 2).first.split("=", 2)
    cookies[name] = value
  end
  response
end
check = ->(condition, message) { raise message unless condition }
csrf = ->(response) { Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')&.[]("content") || raise("Missing CSRF token") }

page = request.call("/session/new")
response = request.call("/session", { "authenticity_token" => csrf.call(page),
  "email_address" => "demo@example.test", "password" => "hello-mailboxes-2026" })
check.call(response.is_a?(Net::HTTPRedirection), "Login failed")
page = request.call("/mailboxes")
check.call(page.is_a?(Net::HTTPSuccess), "Inbox access failed")
address = "dogfood-#{SecureRandom.hex(5)}@#{Rails.configuration.x.mailbox_domain}"
response = request.call("/mailboxes/mailboxes", { "authenticity_token" => csrf.call(page),
  "mailbox[name]" => "Core dogfood", "mailbox[address]" => address })
check.call(response.is_a?(Net::HTTPRedirection), "Mailbox creation failed")
mailbox_path = URI(response["location"]).path
page = request.call(mailbox_path)
check.call(page.body.include?(address), "Created address not visible")

raw = Mail.new do
  from "friend@example.test"
  to address
  subject "Mailbox Kit HTTP dogfood"
  body "Rails persisted this email and Mailbox Kit made it an inbox entry."
end.encoded
envelope = Cloudflare::Email::Envelope.encode(from: "friend@example.test", to: address)
timestamp = Time.current.to_i.to_s
headers = { "Content-Type" => "message/rfc822", "X-CF-Email-Timestamp" => timestamp,
  "X-CF-Email-Signature-Version" => "2", "X-CF-Email-Envelope" => envelope,
  "X-CF-Email-Signature" => Cloudflare::Email::Verification.sign(
    secret: Cloudflare::Email::Credentials.ingress_secret, body: raw,
    timestamp: timestamp, version: "2", envelope: envelope) }
2.times do
  response = request.call("/rails/action_mailbox/cloudflare/inbound_emails", nil, headers, raw)
  check.call(response.is_a?(Net::HTTPSuccess), "Signed delivery/replay failed")
end
page = request.call(mailbox_path)
links = Nokogiri::HTML(page.body).css('a[href*="/messages/"]')
check.call(links.length == 1, "Expected one inbox entry after replay")
message_path = links.first["href"]
message = request.call(message_path)
check.call(message.body.include?("Rails persisted this email"), "Message preview missing")
id = message_path.split("/").last
%w[mark_read archive].each do |action|
  response = request.call("#{mailbox_path}/#{action}", {
    "authenticity_token" => csrf.call(message), "message_id" => id,
    "read" => "true", "archived" => "true" })
  check.call(response.is_a?(Net::HTTPRedirection), "#{action} failed")
end
MailboxKit::Mailboxes.for_tenant(MailboxProvisioning::KEY) do |session|
  entry = session.messages(mailbox_path.split("/").last).find(id)
  check.call(entry.read_at && entry.archived_at, "Read/archive state not persisted")
  check.call(ActionMailbox::InboundEmail.find(entry.inbound_email_id).raw_email.download == raw, "Raw MIME changed")
end
puts "PASS: HTTP login, CSRF, mailbox creation, signed ingress/replay, read and archive; exact MIME retained."
puts "Inbox: #{mailbox_path} (synthetic local mail only)"
