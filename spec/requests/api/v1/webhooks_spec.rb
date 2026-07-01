require "rails_helper"

RSpec.describe "Api::V1::Webhooks#scan_results", type: :request do
  let(:attachment) { create(:attachment, :pending) }
  let(:secret) { ENV.fetch("SCAN_WEBHOOK_SIGNING_SECRET") }

  def signed_post(body_hash)
    body = body_hash.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    post "/api/v1/webhooks/scan_results", params: body, headers: {
      "Content-Type" => "application/json",
      "X-Vendor-Signature" => signature
    }
  end

  it "accepts a correctly-signed clean result and marks the attachment processed" do
    signed_post(external_reference_id: attachment.external_reference_id, result: "clean")

    expect(response).to have_http_status(:no_content)
    expect(attachment.reload.status).to eq("processed")
  end

  it "accepts a correctly-signed malicious result and quarantines the attachment" do
    signed_post(external_reference_id: attachment.external_reference_id, result: "malicious")

    expect(response).to have_http_status(:no_content)
    expect(attachment.reload.status).to eq("quarantined")
  end

  it "rejects a missing signature" do
    post "/api/v1/webhooks/scan_results",
         params: { external_reference_id: attachment.external_reference_id, result: "clean" }.to_json,
         headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(attachment.reload.status).to eq("pending")
  end

  it "rejects a signature computed with the wrong secret" do
    body = { external_reference_id: attachment.external_reference_id, result: "clean" }.to_json
    bad_signature = OpenSSL::HMAC.hexdigest("SHA256", "wrong-secret", body)

    post "/api/v1/webhooks/scan_results", params: body, headers: {
      "Content-Type" => "application/json",
      "X-Vendor-Signature" => bad_signature
    }

    expect(response).to have_http_status(:unauthorized)
    expect(attachment.reload.status).to eq("pending")
  end

  it "rejects a signature that was valid for a different body (tamper detection)" do
    real_body = { external_reference_id: attachment.external_reference_id, result: "clean" }.to_json
    signature_for_real_body = OpenSSL::HMAC.hexdigest("SHA256", secret, real_body)
    tampered_body = { external_reference_id: attachment.external_reference_id, result: "malicious" }.to_json

    post "/api/v1/webhooks/scan_results", params: tampered_body, headers: {
      "Content-Type" => "application/json",
      "X-Vendor-Signature" => signature_for_real_body
    }

    expect(response).to have_http_status(:unauthorized)
    expect(attachment.reload.status).to eq("pending")
  end

  it "404s for an unknown external_reference_id even with a valid signature" do
    signed_post(external_reference_id: SecureRandom.uuid, result: "clean")
    expect(response).to have_http_status(:not_found)
  end

  it "rejects an unrecognized result value" do
    signed_post(external_reference_id: attachment.external_reference_id, result: "definitely-not-malware-trust-me")
    expect(response).to have_http_status(:bad_request)
    expect(attachment.reload.status).to eq("pending")
  end
end
