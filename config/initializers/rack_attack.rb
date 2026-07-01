Rails.application.config.middleware.use Rack::Attack

class Rack::Attack
  cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
end

# The throttle cache lives in Redis, outside the per-example DB transaction
# rollback the test suite relies on for isolation — without this, repeated
# sign-ins/API calls across the whole spec run share one counter and
# eventually trip a real throttle, failing unrelated specs. Rate limiting
# itself is exercised in its own request spec against Rack::Attack
# directly, not incidentally through every other spec's login flow.
Rack::Attack.enabled = false if Rails.env.test?

Rack::Attack.safelist("healthcheck") { |req| req.path == "/healthz" }

# Admin login: throttle by IP and by the attempted email independently, so
# a distributed attempt (many IPs, one target email) and a single-IP spray
# (one IP, many emails) are both bounded. This sits alongside, not instead
# of, Devise's :lockable (account-level lockout after repeated failures).
Rack::Attack.throttle("logins/ip", limit: 10, period: 60) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

Rack::Attack.throttle("logins/email", limit: 10, period: 60) do |req|
  req.params.dig("user", "email").to_s.downcase.presence if req.path == "/users/sign_in" && req.post?
end

# API token authentication: bounds how fast an attacker can try candidate
# tokens against any endpoint under /api/v1, independent of which endpoint
# they hit.
Rack::Attack.throttle("api_token_auth/ip", limit: 60, period: 60) do |req|
  req.ip if req.path.start_with?("/api/v1/")
end

# Presigned URL issuance specifically: even a *valid* token should not be
# able to mint an unbounded number of download URLs per minute (bulk
# exfiltration guard), independent of the general per-IP API throttle
# above, which a distributed client could otherwise spread across IPs
# while reusing one stolen token.
Rack::Attack.throttle("attachment_downloads/token", limit: 30, period: 60) do |req|
  req.get_header("HTTP_X_API_TOKEN") if req.path.match?(%r{\A/api/v1/attachments/\d+/download\z}) && req.get?
end

# Inbound vendor scan-results webhook: generous but bounded, independent
# of signature verification (this is a network-layer guard, not a
# substitute for HMAC verification in WebhooksController).
Rack::Attack.throttle("scan_webhook/ip", limit: 120, period: 60) do |req|
  req.ip if req.path == "/api/v1/webhooks/scan_results" && req.post?
end

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  [429, { "Content-Type" => "application/json", "Retry-After" => match_data[:period].to_s },
   [{ error: "Too many requests" }.to_json]]
end
