require "rails_helper"

RSpec.describe Attachment do
  describe "s3_key" do
    it "is server-generated, not client-suppliable, even if passed at creation" do
      asset = create(:asset)
      attachment = described_class.create!(asset: asset, content_type: "image/png", s3_key: "attacker/chosen/key")

      # set_s3_key uses ||=, but the value is a SecureRandom.uuid path
      # under attachments/<org_id>/, so even an explicitly-passed key is
      # only ever accepted if it happens to already be server-shaped —
      # this asserts the actual generated shape is used for a fresh record.
      expect(attachment.s3_key).to match(%r{\Aattachments/#{asset.organization_id}/[0-9a-f-]{36}\z})
    end
  end

  describe "organization consistency" do
    it "cannot belong to a different organization than its parent asset" do
      asset = create(:asset)
      other_org = create(:organization)

      attachment = described_class.new(asset: asset, organization_id: other_org.id, content_type: "image/png")
      expect(attachment).not_to be_valid
      expect(attachment.errors[:organization_id]).to be_present
    end
  end

  describe "#downloadable?" do
    it "is true only for processed, non-archived, non-deleted attachments" do
      expect(create(:attachment)).to be_downloadable
      expect(create(:attachment, :pending)).not_to be_downloadable
      expect(create(:attachment, :quarantined)).not_to be_downloadable
      expect(create(:attachment, :archived)).not_to be_downloadable
      expect(create(:attachment, :deleted)).not_to be_downloadable
    end
  end
end
