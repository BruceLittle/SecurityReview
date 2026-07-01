require "rails_helper"

RSpec.describe "Admin::ApiTokens", type: :request do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }

  let(:platform_admin) { create(:user, :platform_admin) }
  let(:org_a_admin) { create(:user, :org_admin, organization: org_a) }
  let(:org_a_member) { create(:user, organization: org_a) }

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: user.password } }
  end

  describe "admin-only endpoints" do
    it "denies a plain member (non-admin) any access to the console" do
      sign_in_as(org_a_member)
      get admin_api_tokens_path
      expect(response).to have_http_status(:forbidden)
    end

    it "denies access entirely to an unauthenticated visitor" do
      get admin_api_tokens_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "org scoping for org_admin" do
    it "only lists tokens for the admin's own organization" do
      token_a = ApiToken.generate!(organization: org_a, created_by_user: platform_admin, name: "a").record
      ApiToken.generate!(organization: org_b, created_by_user: platform_admin, name: "b")

      sign_in_as(org_a_admin)
      get admin_api_tokens_path

      expect(response.body).to include(token_a.name)
    end

    it "refuses to let an org_admin issue a token for another organization" do
      sign_in_as(org_a_admin)

      post admin_api_tokens_path, params: { api_token: { name: "cross-org", organization_id: org_b.id, ttl_days: 30 } }

      created = ApiToken.order(:created_at).last
      expect(created.organization_id).to eq(org_a.id) # forced to the caller's own org regardless of the submitted param
    end

    it "404s when an org_admin tries to revoke another organization's token" do
      other_org_token = ApiToken.generate!(organization: org_b, created_by_user: platform_admin, name: "b").record

      sign_in_as(org_a_admin)
      delete admin_api_token_path(other_org_token)

      expect(response).to have_http_status(:not_found)
      expect(other_org_token.reload).not_to be_revoked
    end
  end

  describe "platform_admin cross-org access" do
    it "can issue a token for any organization" do
      sign_in_as(platform_admin)

      post admin_api_tokens_path, params: { api_token: { name: "cross-org", organization_id: org_b.id, ttl_days: 30 } }

      created = ApiToken.order(:created_at).last
      expect(created.organization_id).to eq(org_b.id)
    end
  end

  describe "token issuance" do
    it "shows the plaintext token exactly once and stores only its digest" do
      sign_in_as(org_a_admin)
      post admin_api_tokens_path, params: { api_token: { name: "one-time", ttl_days: 30 } }

      expect(response.body).to match(/srv_[\w-]+/)
      plaintext = response.body[/srv_[\w-]+/]

      created = ApiToken.order(:created_at).last
      expect(created.token_digest).to eq(ApiToken.digest(plaintext))
      expect(created.token_digest).not_to eq(plaintext)
    end

    it "rejects a ttl beyond the maximum" do
      sign_in_as(org_a_admin)
      post admin_api_tokens_path, params: { api_token: { name: "too-long", ttl_days: 10_000 } }

      created = ApiToken.order(:created_at).last
      expect(created.expires_at).to be <= Time.current + ApiToken::MAX_TTL
    end
  end
end
