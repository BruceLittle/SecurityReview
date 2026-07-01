# Wraps AuditLog.record! so every controller-initiated audit entry pulls
# actor/organization/ip from the current request context the same way,
# rather than each controller assembling those fields by hand (and
# risking a copy-paste mistake that drops the ip or attributes an action
# to the wrong actor).
module Auditable
  extend ActiveSupport::Concern

  private

  def audit!(action:, auditable: nil, organization: current_audit_organization, metadata: {})
    AuditLog.record!(
      action: action,
      actor: current_audit_actor,
      organization: organization,
      auditable: auditable,
      ip_address: request.remote_ip,
      metadata: metadata
    )
  end

  # Overridden by including controllers: Api::V1::BaseController's actor is
  # the ApiToken; Admin::BaseController's actor is the signed-in User.
  def current_audit_actor
    nil
  end

  def current_audit_organization
    nil
  end
end
