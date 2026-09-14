# Mailbox Kit dogfood — 2026-09-14

This standalone Rails app now mounts the core management engine and calls
`MailboxKit::Mailboxes` for inbox operations. Cloudflare remains the authenticated
ingress and optional sending integration. Rails owns raw storage and processing.

Verified locally:

- 22 Rails tests, 102 assertions: sessions, ownership isolation, inbox/alias
  creation, signed ingress, replay, raw attachments, read/archive and retention.
- `script/verify_local_inbox.rb` against the running server: real HTTP login and
  CSRF, inbox creation, signed delivery twice, exactly one inbox entry, reading,
  archiving and byte-for-byte retained MIME.
- RuboCop passes.

Repeat the HTTP exercise after starting Rails with the matching port:

```sh
PORT=3128 bin/rails runner script/verify_local_inbox.rb
```

The script uses the seeded development login and loopback only. Each run leaves a
new demonstration inbox and archived synthetic message for inspection. It never
sends external email.

The shared preview browser opened the upgraded app, but its snapshot and evaluation
tools failed repeatedly. Automated browser interaction is therefore not claimed;
the HTTP test and Rails integration tests provide the recorded UI-flow evidence.
Cloudflare DNS, SMTP delivery and outage retries were not exercised in this run.

Dogfooding caught an old-schema constraint requiring Cloudflare account IDs even
for receiving-only domains. The primary directory migration relaxes that constraint
without changing existing values; the separate message index migration preserves
all memberships. The fix is upstream in Cloudflare Email PR #22.
