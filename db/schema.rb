# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_13_194544) do
  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cloudflare_email_addresses", force: :cascade do |t|
    t.string "address", null: false
    t.boolean "catch_all", default: false, null: false
    t.text "catch_all_evidence"
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "local_part", null: false
    t.integer "mailbox_id", null: false
    t.text "provisioning_evidence"
    t.bigint "receiving_domain_id", null: false
    t.string "state", default: "pending", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "idx_cf_email_mailbox_address", unique: true
    t.index ["mailbox_id"], name: "idx_cf_email_address_mailbox"
    t.index ["receiving_domain_id"], name: "idx_cf_email_domain_catch_all", unique: true, where: "catch_all = TRUE AND state = 'active'"
  end

  create_table "cloudflare_email_event_receipts", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "message_id", null: false
    t.text "payload_json", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_id"], name: "idx_cf_email_receipts_account_event", unique: true
    t.index ["account_id", "message_id"], name: "idx_cf_email_receipts_account_message"
    t.index ["state", "id"], name: "idx_cf_email_receipts_replay"
  end

  create_table "cloudflare_email_mailbox_messages", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "inbound_email_id", null: false
    t.integer "mailbox_id", null: false
    t.datetime "read_at"
    t.string "recipient", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.index ["mailbox_id", "inbound_email_id"], name: "idx_cf_email_mailbox_inbound", unique: true
    t.index ["tenant_key", "mailbox_id", "archived_at", "id"], name: "idx_cf_email_mailbox_inbox"
  end

  create_table "cloudflare_email_mailbox_outbound_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "mailbox_id", null: false
    t.integer "outbound_delivery_id", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.index ["mailbox_id"], name: "idx_cf_email_outbound_mailbox"
    t.index ["outbound_delivery_id"], name: "idx_cf_email_mailbox_outbound", unique: true
  end

  create_table "cloudflare_email_mailboxes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "owner_ref"
    t.string "state", default: "active", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_key", "owner_ref"], name: "idx_cf_email_mailbox_owner"
  end

  create_table "cloudflare_email_outbound_deliveries", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_class"
    t.string "from_address", null: false
    t.binary "mime_message", null: false
    t.string "operation_key", null: false
    t.string "provider_message_id"
    t.text "recipients_json", null: false
    t.datetime "request_started_at"
    t.text "response_json"
    t.string "snapshot_digest", null: false
    t.string "state", default: "prepared", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "operation_key"], name: "idx_cf_email_outbound_operation", unique: true
    t.index ["account_id", "provider_message_id"], name: "idx_cf_email_outbound_provider"
    t.index ["state", "id"], name: "idx_cf_email_outbound_pending"
  end

  create_table "cloudflare_email_outbound_recipients", force: :cascade do |t|
    t.string "acceptance_state", default: "prepared", null: false
    t.datetime "created_at", null: false
    t.datetime "occurred_at"
    t.integer "outbound_delivery_id", null: false
    t.string "recipient", null: false
    t.string "state", default: "prepared", null: false
    t.boolean "terminal", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["outbound_delivery_id", "recipient"], name: "idx_cf_email_outbound_recipient", unique: true
  end

  create_table "cloudflare_email_outbound_reconciliations", force: :cascade do |t|
    t.string "actor", null: false
    t.datetime "created_at", null: false
    t.text "evidence", null: false
    t.integer "outbound_delivery_id", null: false
    t.string "outcome", null: false
    t.string "provider_message_id"
    t.text "reason", null: false
    t.text "recipients_json"
    t.datetime "updated_at", null: false
    t.index ["outbound_delivery_id"], name: "idx_cf_email_reconciliation_delivery"
  end

  create_table "cloudflare_email_provider_correlations", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.bigint "outbound_delivery_id", null: false
    t.string "recipient", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "message_id", "recipient", "tenant_key", "outbound_delivery_id"], name: "idx_cf_provider_correlations_identity", unique: true
    t.index ["account_id", "message_id", "recipient"], name: "idx_cf_provider_correlations_lookup"
  end

  create_table "cloudflare_email_receiving_domains", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.text "provisioning_evidence"
    t.boolean "sending_enabled", default: false, null: false
    t.string "state", default: "pending", null: false
    t.string "tenant_key", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["domain"], name: "idx_cf_email_directory_domain", unique: true
    t.index ["tenant_key", "state"], name: "idx_cf_email_directory_tenant"
  end

  create_table "cloudflare_email_shared_event_receipts", force: :cascade do |t|
    t.string "account_id", null: false
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "message_id", null: false
    t.text "payload_json", null: false
    t.string "recipient", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_id"], name: "idx_cf_shared_events_identity", unique: true
    t.index ["state", "id"], name: "idx_cf_shared_events_replay"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cloudflare_email_addresses", "cloudflare_email_mailboxes", column: "mailbox_id"
  add_foreign_key "cloudflare_email_mailbox_messages", "cloudflare_email_mailboxes", column: "mailbox_id"
  add_foreign_key "cloudflare_email_mailbox_outbound_messages", "cloudflare_email_mailboxes", column: "mailbox_id"
  add_foreign_key "cloudflare_email_mailbox_outbound_messages", "cloudflare_email_outbound_deliveries", column: "outbound_delivery_id"
  add_foreign_key "cloudflare_email_outbound_recipients", "cloudflare_email_outbound_deliveries", column: "outbound_delivery_id"
  add_foreign_key "cloudflare_email_outbound_reconciliations", "cloudflare_email_outbound_deliveries", column: "outbound_delivery_id"
  add_foreign_key "sessions", "users"
end
