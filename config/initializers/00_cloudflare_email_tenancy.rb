# Single database: no configuration is necessary.
# Separate tenant databases: configure BEFORE the optional models load.
# Replace these application-specific adapter names with your own:
# require "cloudflare/email/tenancy"
# MailboxKit::Tenancy.configure(
#   base_class: TenantRecord,
#   switch: ->(key, &block) { TenantRecord.with_tenant(key, &block) },
#   current: -> { TenantRecord.current_tenant }
# )
# require "cloudflare/email/mailboxes/configuration"
# MailboxKit::Mailboxes.configure(directory_base: SharedRecord)
# ActionMailbox and ActiveStorage must use this same tenant connection.
# See docs/mailboxes.md for the complete application setup.
