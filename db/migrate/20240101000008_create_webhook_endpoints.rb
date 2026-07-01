class CreateWebhookEndpoints < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_endpoints do |t|
      t.references :organization, null: false, foreign_key: true

      t.string :url, null: false
      # HMAC secret used to sign outgoing deliveries. Unlike ApiToken, this
      # must be *reversible* (we need the plaintext later to compute each
      # delivery's signature), so it is encrypted at rest via
      # ActiveRecord::Encryption (see WebhookEndpoint `encrypts`) rather
      # than one-way hashed. The encryption key lives in Rails credentials /
      # KMS, never in this column or in application code.
      t.string :signing_secret, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
