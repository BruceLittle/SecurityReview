require "devise/orm/active_record"

Devise.setup do |config|
  config.mailer_sender = "no-reply@example.com"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 12..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # Admin/org-user sessions expire after a period of inactivity.
  config.timeout_in = 30.minutes

  # Lock out after repeated failed logins (paired with rack-attack throttling
  # on the sign-in endpoint itself).
  config.lock_strategy = :failed_attempts
  config.unlock_strategy = :time
  config.maximum_attempts = 10
  config.unlock_in = 1.hour
end
