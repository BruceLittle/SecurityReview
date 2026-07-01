source "https://rubygems.org"

ruby "3.3.6"

gem "bootsnap", require: false
gem "pg", "~> 1.5"
gem "puma", "~> 6.4"
gem "rails", "~> 8.0"

# Auth
gem "devise", "~> 4.9"       # session-based auth for the admin web panel
gem "pundit", "~> 2.3"       # authorization policies, org-scoped

# Background jobs
gem "redis", "~> 5.1" # backs both Sidekiq and the Rack::Attack throttle cache
gem "sidekiq", "~> 7.2"
gem "sidekiq-cron", "~> 1.12"
# Pinned: connection_pool 3.x changed its keyword-arg signature in a way
# that's incompatible with ActiveSupport 7.1's RedisCacheStore (raises
# "wrong number of arguments" building the pool) — 2.4.x is the last line
# compatible with both Sidekiq 7 and ActiveSupport 7.1.
gem "connection_pool", "~> 2.4"

# AWS / S3
gem "aws-sdk-s3", "~> 1.146"

# Security
gem "bcrypt", "~> 3.1"           # Devise password hashing
gem "rack-attack", "~> 6.7"      # rate limiting / throttling
gem "rack-cors", "~> 2.0"        # explicit CORS allowlist
gem "secure_headers", "~> 6.5"   # CSP + standard security headers

# Serialization
gem "jbuilder", "~> 2.12"

group :development do
  gem "listen", "~> 3.8"
end

group :test do
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.3"
  gem "rspec", "~> 3.13" # provides the `rspec` executable itself; rspec-rails only pulls in the libraries
  gem "rspec-rails", "~> 6.1"
  gem "shoulda-matchers", "~> 6.2"
  gem "webmock", "~> 3.23"
end

# Env handling (dev/test only; production uses real env vars / secrets manager)
group :development, :test do
  gem "brakeman", "~> 6.1", require: false
  gem "bundler-audit", "~> 0.9", require: false
  gem "dotenv-rails", "~> 3.1"
  gem "rubocop", "~> 1.63", require: false
  gem "rubocop-rails", "~> 2.24", require: false
end
