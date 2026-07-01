Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false

  config.consider_all_requests_local = true
  config.server_timing = true

  config.action_controller.perform_caching = false

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  config.i18n.raise_on_missing_translations = true

  # Never enabled in dev/test/prod for this app; kept explicit for clarity.
  config.hosts.clear
end
