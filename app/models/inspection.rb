class Inspection < ApplicationRecord
  belongs_to :organization
  belongs_to :mission
  has_many :assets, dependent: :restrict_with_error

  STATUSES = %w[scheduled in_progress completed archived].freeze

  validates :status, inclusion: { in: STATUSES }
  validate :organization_matches_mission

  before_validation :set_organization_from_mission, on: :create

  scope :not_archived, -> { where(archived_at: nil) }

  private

  # organization_id is denormalized from the parent mission so every
  # descendant table can be scoped by a single indexed column. It is set
  # here rather than trusted from params, so it can never drift from the
  # mission's actual owner.
  def set_organization_from_mission
    self.organization_id ||= mission&.organization_id
  end

  def organization_matches_mission
    return if mission.nil? || organization_id == mission.organization_id

    errors.add(:organization_id, "must match the parent mission's organization")
  end
end
