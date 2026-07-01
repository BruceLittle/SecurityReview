require "rails_helper"

RSpec.describe "Api::V1::Missions", type: :request do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:mission_a) { create(:mission, organization: org_a) }
  let(:token_a) { generate_api_token(organization: org_a).plaintext_token }
  let(:token_b) { generate_api_token(organization: org_b).plaintext_token }

  describe "GET /api/v1/missions" do
    it "only returns the caller organization's missions" do
      create(:mission, organization: org_b)
      mission_a

      get "/api/v1/missions", headers: { "X-Api-Token" => token_a }

      ids = response.parsed_body.pluck("id")
      expect(ids).to contain_exactly(mission_a.id)
    end

    it "excludes archived missions" do
      create(:mission, :archived, organization: org_a)
      mission_a

      get "/api/v1/missions", headers: { "X-Api-Token" => token_a }

      ids = response.parsed_body.pluck("id")
      expect(ids).to contain_exactly(mission_a.id)
    end

    it "clamps an out-of-range page rather than erroring" do
      get "/api/v1/missions?page=-5", headers: { "X-Api-Token" => token_a }
      expect(response).to have_http_status(:ok)

      get "/api/v1/missions?page=999999999999", headers: { "X-Api-Token" => token_a }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/missions/:id" do
    it "allows access to the caller's own mission" do
      get "/api/v1/missions/#{mission_a.id}", headers: { "X-Api-Token" => token_a }
      expect(response).to have_http_status(:ok)
    end

    it "404s a cross-organization mission id instead of a 403" do
      get "/api/v1/missions/#{mission_a.id}", headers: { "X-Api-Token" => token_b }
      expect(response).to have_http_status(:not_found)
    end
  end
end
