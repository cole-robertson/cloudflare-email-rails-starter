local = Rails.env.local? && Rails.configuration.x.mailbox_domain.end_with?(".test")
email = ENV.fetch("DEMO_EMAIL") { local ? "demo@example.test" : raise("Set DEMO_EMAIL") }
password = ENV.fetch("DEMO_PASSWORD") { local ? "hello-mailboxes-2026" : raise("Set DEMO_PASSWORD") }
evidence = ENV.fetch("MAILBOX_ROUTE_EVIDENCE") do
  local ? "Local signed-ingress demo only; no Cloudflare DNS or route claimed" :
    raise("Set MAILBOX_ROUTE_EVIDENCE after verifying your domain catch-all routes to the Worker")
end
account_id = ENV.fetch("CLOUDFLARE_ACCOUNT_ID") { local ? "local-demo" : raise("Set CLOUDFLARE_ACCOUNT_ID") }

user = User.find_or_create_by!(email_address: email) { |u| u.password = password }
inboxes = Cloudflare::Email::Mailboxes
domain = inboxes::ReceivingDomain.find_by(domain: Rails.configuration.x.mailbox_domain) ||
  inboxes.register_domain(domain: Rails.configuration.x.mailbox_domain,
    tenant_key: MailboxProvisioning::KEY, account_id: account_id)
raise "Domain belongs to another app/account" unless domain.tenant_key == MailboxProvisioning::KEY && domain.account_id == account_id
inboxes.activate_domain!(domain.id, evidence: evidence, sending_enabled: false)
inboxes.for_tenant(MailboxProvisioning::KEY) do |session|
  unless session.mailboxes.exists?(owner_ref: "User:#{user.id}")
    MailboxProvisioning.create(user: user, name: "Hello world", address: "hello@#{domain.domain}")
  end
end
puts "Mailbox ready for #{email}. Existing passwords are never reset by seeds."
