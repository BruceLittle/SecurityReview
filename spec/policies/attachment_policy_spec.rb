require "rails_helper"

RSpec.describe AttachmentPolicy do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:attachment) do
    create(:attachment, asset: create(:asset, inspection: create(:inspection, mission: create(:mission, organization: org_a))))
  end
  let(:token_a) { generate_api_token(organization: org_a).record }
  let(:token_b) { generate_api_token(organization: org_b).record }

  it "permits show/download for a token in the same organization" do
    policy = described_class.new(token_a, attachment)
    expect(policy.show?).to be true
    expect(policy.download?).to be true
  end

  it "denies show/download for a token in a different organization" do
    policy = described_class.new(token_b, attachment)
    expect(policy.show?).to be false
    expect(policy.download?).to be false
  end

  describe "Scope" do
    it "excludes soft-deleted attachments and other organizations' attachments" do
      create(:attachment, :deleted, asset: attachment.asset)
      other_org_attachment = create(:attachment,
                                    asset: create(:asset,
                                                  inspection: create(:inspection,
                                                                     mission: create(:mission, organization: org_b))))

      resolved = described_class::Scope.new(token_a, Attachment.all).resolve

      expect(resolved).to include(attachment)
      expect(resolved).not_to include(other_org_attachment)
      expect(resolved.count).to eq(1)
    end
  end
end
