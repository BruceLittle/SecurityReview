require "rails_helper"

# Rack::Attack is disabled globally in test (see
# config/initializers/rack_attack.rb) so the throttle's shared Redis
# counter doesn't leak between unrelated specs. This is the one place it's
# turned back on, deliberately, to exercise the throttle itself; the
# counter is reset first so a prior spec's login attempts (recorded before
# Rack::Attack.enabled was flipped off) can't fail this one instead.
RSpec.describe "Rack::Attack throttling", type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.reset!
    example.run
    Rack::Attack.reset!
    Rack::Attack.enabled = false
  end

  # Rack::Attack's throttle uses a fixed time window (period seconds wide).
  # Sending exactly limit+1 requests can straddle a window boundary under
  # slow/loaded conditions (e.g. the full suite vs. this file alone) and
  # never trip — so instead of asserting the exact Nth request is blocked,
  # send a comfortable multiple of the limit and assert a 429 shows up
  # somewhere in there, which holds regardless of window alignment.
  it "throttles repeated login attempts from the same IP" do
    user = create(:user, :org_admin)

    statuses = Array.new(30) do
      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }
      response.status
    end

    expect(statuses).to include(429)
  end

  it "throttles repeated API requests from the same IP independent of token validity" do
    statuses = Array.new(150) do
      get "/api/v1/missions", headers: { "X-Api-Token" => "srv_not-a-real-token" }
      response.status
    end

    expect(statuses).to include(429)
  end
end
