namespace :demo do
  desc "Deliver a synthetic hello-world email through the signed local ingress (development only)"
  task receive: :environment do
    abort "This demo is development-only" unless Rails.env.development?
    require "cloudflare/email/verification"
    require "net/http"
    recipient = ENV.fetch("TO", "hello@#{Rails.configuration.x.mailbox_domain}")
    body = Mail.new do
      from "friend@example.test"
      to recipient
      subject "Hello from your Cloudflare mailbox"
      message_id "#{SecureRandom.uuid}@example.test"
      text_part { body "Hello, world!\n\nRails stored this message through the gem's signed ingress. Create another mailbox in the UI, then run TO=that-address bin/rails demo:receive.\n" }
      html_part { body "<h1>Hello, world!</h1><p>The inbox safely shows the plain-text part.</p>" }
      add_file filename: "hello.txt", content: "An attachment retained in the original email."
    end.encoded
    envelope = Cloudflare::Email::Envelope.encode(from: "friend@example.test", to: recipient)
    timestamp = Time.current.to_i.to_s
    signature = Cloudflare::Email::Verification.sign(secret: Cloudflare::Email::Credentials.ingress_secret,
      body: body, timestamp: timestamp, version: "2", envelope: envelope)
    # Loopback only: demo credentials and MIME never go to an external server.
    uri = URI("http://127.0.0.1:#{Integer(ENV.fetch('PORT', '3000'))}/rails/action_mailbox/cloudflare/inbound_emails")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "message/rfc822"
    request["X-CF-Email-Timestamp"] = timestamp
    request["X-CF-Email-Signature"] = signature
    request["X-CF-Email-Signature-Version"] = "2"
    request["X-CF-Email-Envelope"] = envelope
    request.body = body
    response = Net::HTTP.start(uri.host, uri.port, nil, nil, nil, nil,
      open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
    abort "Ingress returned #{response.code}; check mailbox activation and log/development.log" unless response.is_a?(Net::HTTPSuccess)
    puts "Delivered locally to #{recipient}. Open /mailboxes to read it. No external email was sent."
  end
end
