# This file is auto-generated from the current state of the database by
# `bin/rails db:schema:dump`. It is committed so a fresh environment can be
# built with `bin/rails db:schema:load` instead of replaying every migration.

ActiveRecord::Schema[7.1].define(version: 2024_01_01_000009) do
  enable_extension "plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "created_by_user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_api_tokens_on_created_by_user_id"
    t.index ["organization_id", "revoked_at"], name: "index_api_tokens_on_organization_id_and_revoked_at"
    t.index ["organization_id"], name: "index_api_tokens_on_organization_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "inspection_id", null: false
    t.string "asset_type", null: false
    t.string "identifier", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inspection_id"], name: "index_assets_on_inspection_id"
    t.index ["organization_id", "inspection_id"], name: "index_assets_on_organization_id_and_inspection_id"
    t.index ["organization_id"], name: "index_assets_on_organization_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "asset_id", null: false
    t.bigint "uploaded_by_user_id"
    t.string "s3_key", null: false
    t.string "content_type", null: false
    t.bigint "byte_size"
    t.string "status", default: "pending", null: false
    t.string "external_reference_id"
    t.datetime "archived_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_attachments_on_asset_id"
    t.index ["deleted_at"], name: "index_attachments_on_deleted_at"
    t.index ["external_reference_id"], name: "index_attachments_on_external_reference_id", unique: true
    t.index ["organization_id", "asset_id"], name: "index_attachments_on_organization_id_and_asset_id"
    t.index ["organization_id"], name: "index_attachments_on_organization_id"
    t.index ["s3_key"], name: "index_attachments_on_s3_key", unique: true
    t.index ["uploaded_by_user_id"], name: "index_attachments_on_uploaded_by_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "organization_id"
    t.string "actor_type", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_type", "actor_id"], name: "index_audit_logs_on_actor_type_and_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_organization_id_and_created_at"
  end

  create_table "inspections", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "mission_id", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "scheduled_at"
    t.datetime "completed_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mission_id"], name: "index_inspections_on_mission_id"
    t.index ["organization_id", "status"], name: "index_inspections_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_inspections_on_organization_id"
  end

  create_table "missions", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "status"], name: "index_missions_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_missions_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.bigint "organization_id"
    t.string "role", default: "member", null: false
    t.boolean "platform_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "webhook_endpoints", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "url", null: false
    t.string "signing_secret", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_webhook_endpoints_on_organization_id"
  end

  add_foreign_key "api_tokens", "organizations"
  add_foreign_key "api_tokens", "users", column: "created_by_user_id"
  add_foreign_key "assets", "inspections"
  add_foreign_key "assets", "organizations"
  add_foreign_key "attachments", "assets"
  add_foreign_key "attachments", "organizations"
  add_foreign_key "attachments", "users", column: "uploaded_by_user_id"
  add_foreign_key "inspections", "missions"
  add_foreign_key "inspections", "organizations"
  add_foreign_key "missions", "organizations"
  add_foreign_key "users", "organizations"
  add_foreign_key "webhook_endpoints", "organizations"
end
