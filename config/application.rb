require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"

Bundler.require(*Rails.groups)

module SecurityReview
  class Application < Rails::Application
    config.load_defaults 8.0

    # API + admin web panel in one app; API defaults to JSON only.
    config.api_only = false

    # Never trust client-controlled headers for request.ip in this deployment
    # (fronted by a single trusted load balancer that sets X-Forwarded-For).
    config.action_dispatch.trusted_proxies = ENV.fetch("TRUSTED_PROXY_CIDRS", "").split(",").map { |cidr| IPAddr.new(cidr) }

    # Do not autoload the terraform/k8s directories.
    config.autoload_paths -= [Rails.root.join("terraform").to_s, Rails.root.join("k8s").to_s]

    config.active_job.queue_adapter = :sidekiq

    # Filtered from logs in addition to config/initializers/filter_parameter_logging.rb
    config.filter_parameters += %i[token api_token password secret signature access_key]
  end
end
