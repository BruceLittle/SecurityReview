class Mission < ApplicationRecord
  belongs_to :organization
  has_many :inspections, dependent: :restrict_with_error

  STATUSES = %w[scheduled in_progress completed archived].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :not_archived, -> { where(archived_at: nil) }
end
