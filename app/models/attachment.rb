# Represents a file (photo, video, report) stored in S3 under a
# server-generated, unguessable key. The S3 key is *never* derived from or
# influenced by client-supplied input (see #set_s3_key) — this is what
# prevents path traversal / arbitrary-object-access via a crafted key, on
# top of the organization-scoping enforced at the controller/policy layer.
class Attachment < ApplicationRecord
  STATUSES = %w[pending processed quarantined].freeze

  belongs_to :organization
  belongs_to :asset
  belongs_to :uploaded_by_user, class_name: "User", optional: true

  has_many :audit_logs, as: :auditable, dependent: :nullify

  validates :content_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :s3_key, presence: true, uniqueness: true

  validate :organization_matches_asset

  before_validation :set_organization_from_asset, on: :create
  before_validation :set_s3_key, on: :create
  before_validation :set_external_reference_id, on: :create

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :not_archived, -> { where(archived_at: nil) }

  # Files flagged by the vendor scan (see WebhooksController) as malicious
  # or policy-violating are quarantined and can never be downloaded again,
  # regardless of who asks or what token is used.
  def downloadable?
    deleted_at.nil? && archived_at.nil? && status == "processed"
  end

  def quarantine!
    update!(status: "quarantined")
  end

  def mark_processed!
    update!(status: "processed")
  end

  private

  def set_organization_from_asset
    self.organization_id ||= asset&.organization_id
  end

  def organization_matches_asset
    return if asset.nil? || organization_id == asset.organization_id

    errors.add(:organization_id, "must match the parent asset's organization")
  end

  # Unconditional, not ||= : any inbound value (however it got set — strong
  # params already exclude it, but the model must not depend on that being
  # the only line of defense) is always overwritten with a fresh
  # server-generated value on create.
  def set_s3_key
    self.s3_key = "attachments/#{organization_id}/#{SecureRandom.uuid}"
  end

  def set_external_reference_id
    self.external_reference_id = SecureRandom.uuid
  end
end
