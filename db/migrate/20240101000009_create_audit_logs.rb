class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      # No foreign keys to organizations/users/api_tokens on purpose: audit
      # rows must remain even if the actor or org is later deleted, and
      # writes here must never be blocked by referential integrity.
      t.bigint :organization_id
      t.string :actor_type, null: false # "User" | "ApiToken" | "System"
      t.bigint :actor_id

      t.string :action, null: false # e.g. "attachment.download", "api_token.create"
      t.string :auditable_type
      t.bigint :auditable_id

      t.string :ip_address
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, %i[organization_id created_at]
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, %i[actor_type actor_id]
    add_index :audit_logs, :action
  end
end
