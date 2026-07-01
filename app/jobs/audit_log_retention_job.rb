class AuditLogRetentionJob < ApplicationJob
  queue_as :default

  RETENTION_PERIOD = 2.years

  def perform
    AuditLog.where(created_at: ...(RETENTION_PERIOD.ago)).in_batches.delete_all
  end
end
