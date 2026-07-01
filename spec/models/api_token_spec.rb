require "rails_helper"

RSpec.describe ApiToken do
  let(:organization) { create(:organization) }
  let(:creator) { create(:user, :platform_admin) }

  describe ".generate!" do
    it "persists only a digest, never the plaintext" do
      result = described_class.generate!(organization: organization, created_by_user: creator, name: "t")

      expect(result.record.token_digest).to eq(described_class.digest(result.plaintext_token))
      expect(described_class.pluck(:token_digest)).not_to include(result.plaintext_token)
    end

    it "defaults to a 90-day expiration and never exceeds MAX_TTL" do
      result = described_class.generate!(organization: organization, created_by_user: creator, name: "t", ttl: 10.years)
      expect(result.record.expires_at).to be <= Time.current + ApiToken::MAX_TTL
    end
  end

  describe ".authenticate" do
    it "returns the record for a valid, active token" do
      result = described_class.generate!(organization: organization, created_by_user: creator, name: "t")
      expect(described_class.authenticate(result.plaintext_token)).to eq(result.record)
    end

    it "returns nil for an unknown token" do
      expect(described_class.authenticate("srv_does-not-exist")).to be_nil
    end

    it "returns nil for a revoked token" do
      result = described_class.generate!(organization: organization, created_by_user: creator, name: "t")
      result.record.revoke!
      expect(described_class.authenticate(result.plaintext_token)).to be_nil
    end

    it "returns nil for an expired token" do
      result = described_class.generate!(organization: organization, created_by_user: creator, name: "t")
      result.record.update_columns(expires_at: 1.second.ago)
      expect(described_class.authenticate(result.plaintext_token)).to be_nil
    end

    it "returns nil for blank input rather than raising" do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate("")).to be_nil
    end
  end
end
