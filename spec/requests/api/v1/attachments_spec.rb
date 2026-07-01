require "rails_helper"

RSpec.describe "Api::V1::Attachments", type: :request do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }

  let(:mission_a) { create(:mission, organization: org_a) }
  let(:inspection_a) { create(:inspection, mission: mission_a) }
  let(:asset_a) { create(:asset, inspection: inspection_a) }
  let(:attachment_a) { create(:attachment, asset: asset_a) }

  let(:token_a) { generate_api_token(organization: org_a).plaintext_token }
  let(:token_b) { generate_api_token(organization: org_b).plaintext_token }

  def auth_headers(token)
    { "X-Api-Token" => token }
  end

  describe "GET /api/v1/attachments/:id/download" do
    context "allowed object access" do
      it "returns a presigned url for an attachment in the caller's own organization" do
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_a)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["url"]).to be_present
        expect(body["expires_at"]).to be_present
      end

      it "logs the access without ever including the presigned url/signature" do
        expect do
          get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_a)
        end.to change(AuditLog, :count).by(1)

        entry = AuditLog.last
        expect(entry.action).to eq("attachment.download")
        expect(entry.auditable).to eq(attachment_a)
        expect(entry.metadata.to_s).not_to include("Signature=")
        expect(entry.metadata.to_s).not_to include("X-Amz-Signature")
      end

      it "issues a url that expires shortly (bounded lifetime)" do
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_a)

        expires_at = Time.zone.parse(response.parsed_body["expires_at"])
        expect(expires_at).to be_within(5.seconds).of(Time.current + S3PresignedUrlService::GET_EXPIRES_IN)
      end
    end

    context "forbidden cross-customer object access" do
      it "404s (not 403) when a token from org B requests an attachment owned by org A" do
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_b)

        expect(response).to have_http_status(:not_found)
      end

      it "never generates a presigned url for the wrong organization" do
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_b)

        expect(response.parsed_body).not_to have_key("url")
      end
    end

    context "nonexistent object access" do
      it "404s for an id that does not exist" do
        get "/api/v1/attachments/999999999/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "authentication" do
      it "rejects a missing token" do
        get "/api/v1/attachments/#{attachment_a.id}/download"
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects an invalid token" do
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers("srv_not-a-real-token")
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects an expired token" do
        expired = generate_api_token(organization: org_a, ttl: 90.days)
        expired.record.update_columns(expires_at: 1.day.ago)

        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(expired.plaintext_token)
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a revoked token" do
        revoked = generate_api_token(organization: org_a)
        revoked.record.revoke!

        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(revoked.plaintext_token)
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects a token belonging to a suspended organization" do
        org_a.update!(status: "suspended")
        get "/api/v1/attachments/#{attachment_a.id}/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "malformed/edge-case ids" do
      it "treats a negative id as not found, not an error" do
        get "/api/v1/attachments/-1/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:not_found)
      end

      it "treats a non-numeric id as not found, not a 500" do
        get "/api/v1/attachments/not-a-number/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:not_found)
      end

      it "treats duplicate id parameters using only the first/last value, never erroring" do
        get "/api/v1/attachments/#{attachment_a.id}/download?id=#{attachment_a.id}", headers: auth_headers(token_a)
        expect(response).to have_http_status(:ok)
      end
    end

    context "business-state gates" do
      it "refuses to download a quarantined attachment even for its own organization" do
        quarantined = create(:attachment, :quarantined, asset: asset_a)
        get "/api/v1/attachments/#{quarantined.id}/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:conflict)
      end

      it "refuses to download an archived attachment" do
        archived = create(:attachment, :archived, asset: asset_a)
        get "/api/v1/attachments/#{archived.id}/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:conflict)
      end

      it "404s for a soft-deleted attachment (excluded from the scoped query entirely)" do
        deleted = create(:attachment, :deleted, asset: asset_a)
        get "/api/v1/attachments/#{deleted.id}/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:not_found)
      end

      it "refuses to download a still-pending (unscanned) attachment" do
        pending_attachment = create(:attachment, :pending, asset: asset_a)
        get "/api/v1/attachments/#{pending_attachment.id}/download", headers: auth_headers(token_a)
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "GET /api/v1/attachments/:id" do
    it "empty id 404s at the router level" do
      get "/api/v1/attachments//download", headers: auth_headers(token_a)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/assets/:asset_id/attachments" do
    it "creates a pending attachment and returns a bounded-lifetime upload url for the caller's own asset" do
      post "/api/v1/assets/#{asset_a.id}/attachments",
           params: { attachment: { content_type: "image/png" } },
           headers: auth_headers(token_a)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["upload_url"]).to be_present
      expect(Attachment.last.status).to eq("pending")
    end

    it "404s when the asset belongs to another organization" do
      post "/api/v1/assets/#{asset_a.id}/attachments",
           params: { attachment: { content_type: "image/png" } },
           headers: auth_headers(token_b)

      expect(response).to have_http_status(:not_found)
    end

    it "ignores client-supplied organization_id/s3_key/status (mass assignment guard)" do
      post "/api/v1/assets/#{asset_a.id}/attachments",
           params: { attachment: { content_type: "image/png", organization_id: org_b.id, s3_key: "attacker-chosen-key",
                                   status: "processed" } },
           headers: auth_headers(token_a)

      created = Attachment.last
      expect(created.organization_id).to eq(org_a.id)
      expect(created.status).to eq("pending")
      expect(created.s3_key).not_to eq("attacker-chosen-key")
    end
  end
end
