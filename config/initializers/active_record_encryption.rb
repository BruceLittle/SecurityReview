# Keys for ActiveRecord::Encryption (used by WebhookEndpoint#signing_secret).
# Sourced from the deploy platform's secret manager via env vars — never
# committed, never derived from application source. See .env.example.
Rails.application.configure do
  config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", nil)
  config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", nil)
  config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
  config.active_record.encryption.support_unencrypted_data = false
end
