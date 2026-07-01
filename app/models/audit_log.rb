# Append-only audit trail. Rows are written exclusively through
# AuditLog.record! (see Auditable concern) so every entry has a consistent
# shape; there is intentionally no update path and no destroy exposed
# outside of the scheduled retention job.
class AuditLog < ApplicationRecord
  belongs_to :organization, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true
  validates :actor_type, inclusion: { in: %w[User ApiToken System] }

  def self.record!(action:, actor:, organization:, auditable: nil, ip_address: nil, metadata: {})
    create!(
      action: action,
      actor_type: actor&.class&.name || "System",
      actor_id: actor&.id,
      organization_id: organization&.id,
      auditable: auditable,
      ip_address: ip_address,
      # Defense in depth: even though callers should never pass a token/
      # secret in here, strip anything that looks like one before it can
      # ever reach storage or a log line.
      metadata: sanitize_metadata(metadata)
    )
  end

  def self.sanitize_metadata(metadata)
    metadata.to_h.except(:token, :api_token, :password, :secret, :signature, :signing_secret)
  end

  def actor
    return nil if actor_id.nil? || actor_type == "System"

    actor_type.constantize.find_by(id: actor_id)
  end
end
