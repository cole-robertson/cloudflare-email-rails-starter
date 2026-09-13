# Opt in after running db:migrate. Never perform network delivery inside a database transaction.
require "cloudflare/email/active_record"
require "cloudflare/email/send_job"
require "cloudflare/email/replay_events_job"
