# This app uses one verified domain with a Cloudflare catch-all rule to its Worker.
# New addresses need only local registration. Unknown recipients remain rejected
# by Rails: a Worker catch-all is NOT the gem's optional mailbox catch-all.
class MailboxProvisioning
  KEY = "application"

  def self.create(user:, name:, address:)
    Cloudflare::Email::Mailboxes.for_tenant(KEY) do |session|
      Cloudflare::Email::Mailboxes::Mailbox.transaction do
        mailbox = session.create(name: name, address: address, owner_ref: "User:#{user.id}")
        activate(session, session.addresses(mailbox.id).first)
        mailbox
      end
    end
  end

  def self.activate(session, address)
    domain = Cloudflare::Email::Mailboxes::ReceivingDomain.find(address.receiving_domain_id)
    session.activate_address!(address.id, evidence: domain.provisioning_evidence)
  end
end
