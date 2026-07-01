module ApiTokenHelper
  # Returns an OpenStruct(record:, plaintext_token:) — the same shape
  # ApiToken.generate! returns in production — so specs can authenticate
  # requests with the real plaintext while asserting on the persisted
  # record.
  def generate_api_token(organization:, created_by_user: nil, ttl: 90.days)
    created_by_user ||= create(:user, :platform_admin)
    ApiToken.generate!(organization: organization, created_by_user: created_by_user, name: "test-token", ttl: ttl)
  end
end

RSpec.configure do |config|
  config.include ApiTokenHelper
end
