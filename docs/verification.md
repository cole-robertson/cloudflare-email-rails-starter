# Hello-world dogfood verification

Verified September 13, 2026 with Ruby 3.4.5, Rails 8.1.3.1, SQLite 2.9.6,
and **cloudflare-email 0.3.0 installed from RubyGems**. No Git/path gem override
or application monkey patch was used.

## Fresh installation

- Generated a stock Rails app with SQLite, Rails authentication, Action Mailbox,
  and the gem's install/mailboxes generators.
- Cloned the committed example into a new directory without `config/master.key`,
  local databases, uploaded mail, or environment files.
- Ran `bin/setup --skip-server` twice. Both runs passed; the database contained
  exactly one user and one mailbox, and existing passwords were unchanged.
- `bin/rails zeitwerk:check` passed in the fresh checkout.
- Started that checkout's Rails server and ran `PORT=3130 bin/rails demo:receive`.
  The real loopback HTTP ingress succeeded. The raw record reached `delivered`,
  with its full 1,131-byte MIME and `hello.txt` attachment retained.

## Browser walkthrough

Used the shared Chromium preview against the running Rails app:

1. Signed in with the seeded Rails user.
2. Opened the mounted gem engine and the initial mailbox.
3. Created `browser@inbox.example.test` through the normal CSRF-protected form.
4. Added `alias@inbox.example.test` through the alias form. Both addresses showed
   **Accepting mail**.
5. Delivered a signed synthetic email over HTTP to the alias using the demo task.
6. Opened the resulting inbox entry and verified subject, sender, exact envelope
   recipient, plain-text body, and attachment filename.
7. Submitted **Mark read** and **Archive** through the engine forms; reloaded the
   mailbox and confirmed both persisted badges.

Preview screenshots were unavailable, so the walkthrough was checked through
the browser DOM, actual form submissions, and persisted records.

## Automated checks

`bin/rails test`: **21 tests, 99 assertions, no failures/errors/skips**.

Coverage includes the generated Rails authentication tests plus mailbox login,
revoked sessions, owner isolation for direct URLs/mutations/message access,
unrelated-domain rejection, mailbox/alias activation, trusted envelope routing,
byte-exact raw MIME and attachment retention, duplicate ingress, invalid
signatures, unknown/suspended recipients, escaped sender content, and read/archive
state. A regression test also checks HTML rendering after a Turbo sign-in redirect.

RuboCop: 60 files, no offenses. Brakeman: no warnings/errors. Bundler Audit and
Importmap audit: no known vulnerabilities reported. CI repeats these checks and
the clean/idempotent setup on pushes and weekly.

## Findings and boundaries

- The gem supplied all mailbox storage, ingress, and inbox UI behavior. Only
  authentication/ownership and the app's verified-domain activation policy needed
  host code.
- Rails 8.1 currently needs JSON below 3 for its JSON option handling; the starter
  declares that compatibility constraint.
- The engine's default text describes pending address activation. The starter
  activates immediately because its setup asserts an already-routed domain.
- A Cloudflare Worker catch-all does not mean arbitrary recipient addresses are
  accepted into the gem. Unknown/suspended recipients return an error and will
  remain pending in a durable Worker until an operator resolves them.
- This run **did not deploy a new public Rails app, send external email, configure
  DNS, or rehearse a real Cloudflare/R2/Queue outage**. The local task exercises
  signed HTTP ingress and app persistence, not SMTP/provider transport. The README
  gives the separate live setup and outage drill.
- This is an inbound mailbox starter. Compose, outbound provider delivery
  tracking, attachment downloads, and multi-database tenancy are not configured.
  Raw retention follows Action Mailbox's default 30-day incineration unless changed.
