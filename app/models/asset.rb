class Asset < ApplicationRecord
  belongs_to :organization
  belongs_to :inspection
  has_many :attachments, dependent: :restrict_with_error

  validates :asset_type, presence: true
  validates :identifier, presence: true

  validate :organization_matches_inspection

  before_validation :set_organization_from_inspection, on: :create

  private

  def set_organization_from_inspection
    self.organization_id ||= inspection&.organization_id
  end

  def organization_matches_inspection
    return if inspection.nil? || organization_id == inspection.organization_id

    errors.add(:organization_id, "must match the parent inspection's organization")
  end
end
