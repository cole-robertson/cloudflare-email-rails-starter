class MailboxAccess < MailboxKit::Management::Adapter
  ACTIONS = %i[index show create add_address suspend resume show_message mark_read archive].freeze

  def authenticate!
    Current.session = Session.find_by(id: controller.request.cookie_jar.signed[:session_id])
    @user = Current.user
    return true if @user

    controller.redirect_to controller.main_app.new_session_path
    false
  end

  def tenant_key = MailboxProvisioning::KEY
  def owner_ref = "User:#{@user.id}"
  def domains(_session) = [ Rails.configuration.x.mailbox_domain ]
  def mailboxes(session) = session.mailboxes.where(owner_ref: owner_ref)

  def allowed?(action, mailbox = nil)
    @user.present? && ACTIONS.include?(action) && (mailbox.nil? || mailbox.owner_ref == owner_ref)
  end

  def create_mailbox(session, name:, address:)
    MailboxProvisioning.create(user: @user, name: name, address: address)
  end

  def add_address(session, mailbox, address:)
    MailboxProvisioning.activate(session, session.add_address(mailbox.id, address: address))
  end
end
