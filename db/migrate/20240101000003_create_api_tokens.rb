class CreateApiTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :api_tokens do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }

      t.string :name, null: false

      # Only a SHA-256 digest of the token is ever persisted. The plaintext
      # token is shown to the admin exactly once, at creation time, and is
      # unrecoverable afterward. See ApiToken.authenticate.
      t.string :token_digest, null: false

      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.string :last_used_ip

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, %i[organization_id revoked_at]
  end
end
