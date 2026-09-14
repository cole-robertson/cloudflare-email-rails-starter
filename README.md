# Hello, mailbox!

A tiny mailbox app built with **stock Rails 8.1, SQLite, Mailbox Kit, and
Cloudflare Email**. This branch dogfoods both gems at the merged upstream commit
`8502f9ca941b3a0fd2c938ca84da7fa5bac2aefd`; the extraction is not yet on RubyGems.

Sign in, create inboxes and aliases, receive mail, read messages, mark them
read/unread, archive them, and pause receiving. Rails generates the login; the
core gem provides inbox identities, memberships, and the entire mailbox
management UI. Rails stores and processes raw email; Cloudflare verifies incoming
requests. There are no custom mailbox tables, inbox controllers, or React
components. Database multi-tenancy is not enabled.

## Try it locally

You need Ruby 3.4, Bundler, and the usual Rails native build dependencies. No
Cloudflare account, API token, Node build, external email, or DNS change is needed.

```sh
git clone https://github.com/cole-robertson/cloudflare-email-rails-starter.git
cd cloudflare-email-rails-starter
bin/setup
```

Open **http://localhost:3000** and sign in:

- Email: `demo@example.test`
- Password: `hello-mailboxes-2026`

Select **Open your mailboxes**, then **Hello world**. In another terminal:

```sh
bin/rails demo:receive
```

Refresh the inbox and open the message. Its plain-text body and attachment name
appear in the gem's UI; the original MIME and attachment bytes are retained by
Action Mailbox/Active Storage. The viewer intentionally does not render sender
HTML or provide attachment downloads.

Create another mailbox in the UI, for example `support@inbox.example.test`, and
send it a local message:

```sh
TO=support@inbox.example.test bin/rails demo:receive
```

The demo command signs a synthetic message and makes a real HTTP request to your
running Rails server on loopback. It exercises the gem's actual ingress, database
storage, and mailbox association. It does **not** exercise Cloudflare, DNS, SMTP,
or the Worker's durable retry infrastructure. For a different server port, use
the same `PORT` for both `bin/rails server` and `bin/rails demo:receive`.

`bin/setup --skip-server` prepares the app without starting it. Setup is repeatable
and does not reset existing passwords or recreate existing mailboxes. The known
login and `.test` domain are development/test fixtures, not production credentials.
Local password reset emails are written to `tmp/mails` instead of sent externally.

## How little app code is involved?

| File | What belongs to the app |
| --- | --- |
| [MailboxAccess](app/services/mailbox_access.rb) | Connect Rails sessions, restrict each user's mailboxes, and allow one configured domain |
| [MailboxProvisioning](app/services/mailbox_provisioning.rb) | Register and activate addresses on the app's already-routed domain |
| [Initializer](config/initializers/mailbox_demo.rb) | Mount adapter configuration and choose the domain |
| [Seeds](db/seeds.rb) | Create the initial user, domain registration, and hello-world mailbox |
| [MainMailbox](app/mailboxes/main_mailbox.rb) | Optional place for your business logic after the gem has saved the message |

The engine is mounted at `/mailboxes` in [routes](config/routes.rb). Its generic
copy explains that new addresses normally need activation; this demo's small
provisioning adapter activates them immediately on its preconfigured domain.

The fixed `application` registry key scopes gem records in one SQLite database.
`owner_ref` associates a mailbox with a Rails user; the access adapter enforces
ownership. Neither value creates a separate tenant database.

## Create an inbox in code

In `bin/rails console`, after authorizing the action in your own application:

```ruby
user = User.find_by!(email_address: "demo@example.test")
mailbox = MailboxProvisioning.create(
  user: user,
  name: "Receipts",
  address: "receipts@inbox.example.test"
)
```

The same service is called by the UI. To create an account, use Rails' normal
`User.create!(email_address: ..., password: ...)`; there is no public signup or
administrator UI in this starter. Each account only sees its own mailboxes.

The underlying gem API is also available directly:

```ruby
MailboxKit::Mailboxes.for_tenant("application") do |inboxes|
  # The caller must apply its own ownership/authorization scope.
  mine = inboxes.mailboxes.where(owner_ref: "User:#{user.id}")
  entries = inboxes.messages(mine.find(mailbox.id).id)
end
```

## Connect real Cloudflare email

Use the gem's [domain setup worksheet](https://github.com/cole-robertson/cloudflare-email/blob/main/templates/worker/docs/domain-setup.md)
for both `acme@in.example.com` and `invoices@acme.in.example.com`. It cites Rebulk's
working wildcard MX/catch-all pattern, Cloudflare's official documentation, and
the differences a new account must verify. The current Worker templates include
`npm run check:subdomains -- --base in.example.com --labels acme,globex` to inspect
named and fresh MX answers without credentials or configuration changes.

This starter keeps one domain to stay small. In an organization-aware app, once
the dynamic receiving namespace is verified, register each exact organization
domain in Rails and return that organization's allowed domains from the engine
adapter. There is no per-organization Worker allowlist or routine Cloudflare
approval in Rebulk's established pattern. The guide includes the gem API recipe;
database multi-tenancy is still optional.

Deploy this Rails app to an HTTPS host first. Keep SQLite databases and Active
Storage files on persistent storage with backups. Run Solid Queue (`bin/jobs`, or
`SOLID_QUEUE_IN_PUMA=true` for a single server) for Action Mailbox jobs. Configure
your normal Rails production secrets; do not commit credentials to the repo.

1. Choose a receiving domain such as `in.example.com`. Configure Email Routing
   for that exact domain/subdomain. Keep existing Google Workspace/Microsoft 365
   MX records intact; use a dedicated receiving subdomain when appropriate.
2. Set `MAILBOX_DOMAIN` and a random
   `CLOUDFLARE_INGRESS_SECRET` in Rails. Use `openssl rand -hex 32` for the secret.
   Set `APP_HOST` to the application's HTTPS hostname.
3. Use the gem's [Deploy to Cloudflare template](https://github.com/cole-robertson/cloudflare-email/tree/main/templates/deploy-to-cloudflare).
   Enter `https://your-app.com/rails/action_mailbox/cloudflare/inbound_emails`
   and the same ingress secret. It configures R2, Queue delivery, and cron recovery.
4. Configure a **Cloudflare Email Routing catch-all for the intended receiving
   domain** pointing at this Worker. Check the rule's domain scope before saving;
   do not replace an unrelated apex catch-all. Verify that the Worker receives
   mail for this domain before recording your setup evidence.
5. Set `DEMO_EMAIL`, a strong `DEMO_PASSWORD`, and `MAILBOX_ROUTE_EVIDENCE` to your
   actual verification note. Run `RAILS_ENV=production bin/rails db:prepare`
   and `RAILS_ENV=production bin/rails db:seed`.
6. Send real mail to `hello@your-receiving-domain`, verify its raw storage and
   inbox entry, and rehearse a Rails outage in staging. Confirm R2 retains mail
   while Rails is down and drains after recovery without duplicate inbox entries.

Use deployment environment variables; this app does not automatically load `.env`
files. The seed task requires explicit credentials and routing evidence outside
the local `.test` demo. It records your assertion; it does not configure or verify
Cloudflare DNS on your behalf. Demo domain registrations must not be reused as
real verification evidence.

**Why a Worker catch-all?** Once the domain routes to this Worker, creating an
inbox or alias is a local database operation. Rails accepts only registered active
addresses. We do not enable the gem's optional mailbox catch-all that accepts
unknown local parts. With durable delivery, unknown/suspended recipients return
an error and remain pending at Cloudflare: monitor and resolve that backlog rather
than assuming those messages were discarded. The
[recovery guide](https://github.com/cole-robertson/cloudflare-email/blob/main/templates/worker/docs/durable-inbound.md)
explains retention, retries, and capacity limits.

This is a receiving-first starter. The management UI has no compose/send page.
Production password resets or other Rails mailers additionally need a verified
`MAIL_FROM` address and `CLOUDFLARE_API_TOKEN` with sending permission. Outbound
delivery tracking needs its own setup; an inbound Worker does not configure it.
Mailbox Kit retains inbox-associated raw messages through Rails' incineration
hook. Unassociated mail follows Rails' cleanup policy. Choose backups and storage
retention appropriate to your application.

## Recreate from an empty Rails app

The setup began with the ordinary Rails generator, then:

```sh
rails new hello_mailbox --database sqlite3
cd hello_mailbox
# Add the pinned two-gem Git block from this repository's Gemfile, then:
bundle install
bundle add json --version '< 3'
bin/rails generate authentication
bin/rails action_mailbox:install
bin/rails generate cloudflare:email:install --all-envs --scaffold-mailbox --no-deploy-worker
bin/rails generate cloudflare:email:mailboxes
bin/rails db:migrate
```

Then add the small host files listed above, the home page, and engine mount;
require `mailbox_kit/management` after `Bundler.require` in
`config/application.rb`. This repo has those steps completed for you.
The generated `cloudflare-worker/` copy is omitted here because the maintained
deploy template lives in the gem repo. JSON is bounded below 3 for compatibility
with Rails 8.1's JSON option handling.

## Verification and updates

```sh
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager
bin/bundler-audit
bin/importmap audit
```

Tests cover login/session revocation, owner isolation, mailbox/alias creation,
signed ingress, raw attachment retention, deduplication, unknown/suspended
recipients, escaped message rendering, and read/archive state. See
[the dogfood report](docs/verification.md) for the actual run and its limits.
The [Mailbox Kit upgrade report](docs/mailbox-kit-dogfood.md) records this branch's
tests and repeatable HTTP exercise.

CI runs on pushes and weekly, and Dependabot checks dependencies. To dogfood a new
gem release, update both gem requirements together, run the checks, and review
Worker upgrade notes separately. The current immutable Git pin makes this
unreleased integration reproducible without a local checkout. Once both gems are
published, replace it with their released RubyGems requirements.
