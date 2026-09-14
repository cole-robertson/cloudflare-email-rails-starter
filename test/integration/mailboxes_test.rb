require "test_helper"
require "cloudflare/email/verification"

class MailboxesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @domain = MailboxKit::Mailboxes.register_domain(domain: Rails.configuration.x.mailbox_domain,
      tenant_key: MailboxProvisioning::KEY)
    MailboxKit::Mailboxes.activate_domain!(@domain.id, evidence: "Synthetic integration test")
    @mailbox = MailboxProvisioning.create(user: @user, name: "My inbox", address: "hello@#{@domain.domain}")
  end

  test "mailbox UI requires a real unrevoked Rails session" do
    get "/mailboxes"
    assert_redirected_to "/session/new"
    sign_in_as @user
    get "/mailboxes"
    assert_response :success
    assert_select "a", text: "My inbox"
    @user.sessions.destroy_all
    get "/mailboxes"
    assert_redirected_to "/session/new"
  end

  test "UI creates an owned active mailbox and alias on the configured domain" do
    sign_in_as @user
    post "/mailboxes/mailboxes", params: { mailbox: { name: "Support", address: "support@#{@domain.domain}", owner_ref: "User:#{users(:two).id}" } }
    assert_response :see_other
    inboxes do |session|
      mailbox = session.mailboxes.find_by!(name: "Support")
      assert_equal "User:#{@user.id}", mailbox.owner_ref
      assert_equal "active", session.addresses(mailbox.id).first.state
      post "/mailboxes/mailboxes/#{mailbox.id}/aliases", params: { address: "help@#{@domain.domain}" }
      assert_response :see_other
      assert_equal [ "active", "active" ], session.addresses(mailbox.id).pluck(:state)
    end
  end

  test "another user cannot view or change someone else's mailbox" do
    sign_in_as users(:two)
    get "/mailboxes"
    assert_response :success
    assert_select "a", text: "My inbox", count: 0
    get "/mailboxes/mailboxes/#{@mailbox.id}"
    assert_response :not_found
    post "/mailboxes/mailboxes/#{@mailbox.id}/suspend"
    assert_response :not_found
    assert_equal "active", @mailbox.reload.state
  end

  test "an unrelated domain cannot be claimed in the UI" do
    sign_in_as @user
    assert_no_difference "MailboxKit::Mailboxes::Mailbox.count" do
      post "/mailboxes/mailboxes", params: { mailbox: { name: "Foreign", address: "hello@someone-else.test" } }
    end
  end

  test "signed delivery retains raw MIME and attachments and retry creates no duplicate" do
    raw = raw_email
    assert_difference "ActionMailbox::InboundEmail.count", 1 do
      deliver(raw)
      assert_response :success
      deliver(raw)
      assert_response :success
    end
    inboxes do |session|
      assert_equal 1, session.messages(@mailbox.id).count
      entry = session.messages(@mailbox.id).first
      inbound = session.inbound_email(@mailbox.id, entry.id)
      assert_equal raw, inbound.raw_email.download
      assert_equal "attachment bytes", inbound.mail.attachments.first.decoded
      assert_equal "hello@#{@domain.domain}", entry.recipient
    end
  end

  test "core attaches existing Rails mail idempotently and retains it until explicitly purged" do
    inbound = ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_email)
    inboxes do |session|
      entry = session.attach(recipient: "hello@#{@domain.domain}", inbound_email_id: inbound.id)
      assert_equal entry.id, session.attach(recipient: "hello@#{@domain.domain}", inbound_email_id: inbound.id).id
      inbound.delivered!
      travel 31.days do
        inbound.incinerate
        assert ActionMailbox::InboundEmail.exists?(inbound.id)
      end
      session.purge_message(@mailbox.id, entry.id)
      assert_not ActionMailbox::InboundEmail.exists?(inbound.id)
    end
  end

  test "aliases deliver into the same mailbox; unknown and suspended recipients are rejected" do
    inboxes do |session|
      MailboxProvisioning.activate(session, session.add_address(@mailbox.id, address: "alias@#{@domain.domain}"))
    end
    deliver(raw_email, recipient: "alias@#{@domain.domain}")
    assert_response :success
    assert_no_difference "ActionMailbox::InboundEmail.count" do
      deliver(raw_email, recipient: "unknown@#{@domain.domain}")
      assert_response :unprocessable_entity
      inboxes { |session| session.suspend(@mailbox.id) }
      deliver(raw_email)
      assert_response :unprocessable_entity
    end
  end

  test "invalid signature cannot persist mail" do
    assert_no_difference "ActionMailbox::InboundEmail.count" do
      deliver(raw_email, signature: "0" * 64)
      assert_response :unauthorized
    end
  end

  test "viewer escapes sender content and read archive controls persist" do
    deliver(raw_email)
    sign_in_as @user
    entry = inboxes { |session| session.messages(@mailbox.id).first }
    path = "/mailboxes/mailboxes/#{@mailbox.id}"
    get "#{path}/messages/#{entry.id}"
    assert_response :success
    assert_includes response.body, "&lt;script&gt;"
    assert_select "script", count: 0
    assert_select "img[src^='https:']", count: 0
    post "#{path}/mark_read", params: { message_id: entry.id, read: "true" }
    assert_response :see_other
    assert entry.reload.read_at
    post "#{path}/archive", params: { message_id: entry.id, archived: "true" }
    assert_response :see_other
    assert entry.reload.archived_at
    sign_in_as users(:two)
    get "#{path}/messages/#{entry.id}"
    assert_response :not_found
  end

  private

  def inboxes(&block)
    MailboxKit::Mailboxes.for_tenant(MailboxProvisioning::KEY, &block)
  end

  def raw_email
    Mail.new do
      from "friend@example.test"
      to "misleading-mime-recipient@example.test"
      subject "Hello <script>alert('x')</script>"
      message_id "#{SecureRandom.uuid}@example.test"
      text_part { body "Hello <script>alert('x')</script>" }
      html_part { body '<img src="https://example.test/tracker"><script>alert(1)</script>' }
      add_file filename: "hello.txt", content: "attachment bytes"
    end.encoded
  end

  def deliver(body, recipient: "hello@#{@domain.domain}", signature: nil)
    envelope = Cloudflare::Email::Envelope.encode(from: "friend@example.test", to: recipient)
    timestamp = Time.current.to_i.to_s
    signature ||= Cloudflare::Email::Verification.sign(secret: Cloudflare::Email::Credentials.ingress_secret,
      body: body, timestamp: timestamp, version: "2", envelope: envelope)
    post "/rails/action_mailbox/cloudflare/inbound_emails", params: body, headers: {
      "CONTENT_TYPE" => "message/rfc822", "HTTP_X_CF_EMAIL_TIMESTAMP" => timestamp,
      "HTTP_X_CF_EMAIL_SIGNATURE" => signature, "HTTP_X_CF_EMAIL_SIGNATURE_VERSION" => "2",
      "HTTP_X_CF_EMAIL_ENVELOPE" => envelope
    }
  end
end
