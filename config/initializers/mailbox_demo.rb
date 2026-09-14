# The demo is one ordinary SQLite database; database tenancy is not enabled.
Rails.application.config.x.mailbox_domain = ENV.fetch("MAILBOX_DOMAIN", "inbox.example.test")

if Rails.env.local?
  ENV["CLOUDFLARE_INGRESS_SECRET"] ||= Rails.application.secret_key_base
end

MailboxKit::Management.configure do |config|
  config.adapter = ->(controller) { MailboxAccess.new(controller) }
  config.back_path = ->(controller) { controller.main_app.root_path }
end
