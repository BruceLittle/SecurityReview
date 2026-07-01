Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true

  # No verbose error pages or stack traces are ever rendered to clients.
  config.consider_all_requests_local = false
  config.action_dispatch.show_exceptions = :none

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.assume_ssl = true
  config.force_ssl = true

  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  config.action_mailer.perform_caching = false

  config.i18n.fallbacks = true

  # Only the deployed hostnames may serve this app (mitigates Host header /
  # DNS-rebinding attacks). Set via env, not hardcoded, per environment.
  config.hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  config.host_authorization = { exclude: ->(request) { request.path == "/healthz" } }
end
