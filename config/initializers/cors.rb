require "rack/cors"

# Only the JSON API is ever exposed cross-origin, and only to an explicit,
# ops-configured allowlist — never "*". The admin console is
# session/cookie-authenticated and is never included in this policy, so a
# malicious page on an allowed API origin still can't ride the admin
# session (browsers don't send /admin's cookie to a fetch() aimed at
# /api, and vice versa; this block only widens *where the API itself* can
# be called from).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

  allow do
    origins allowed_origins

    resource "/api/*",
             headers: :any,
             methods: %i[get post],
             credentials: false, # token is sent via X-Api-Token, not a cookie — no reason to allow credentialed CORS
             max_age: 600
  end
end
