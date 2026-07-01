# Audit logs are read-only from the admin console (no create/update/destroy
# actions are exposed anywhere in the app outside AuditLog.record! itself
# and the scheduled retention job).
class AuditLogPolicy < ApplicationPolicy
  def index? = true

  def show?
    user.platform_admin? || record.organization_id == user.organization_id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scoped_to_own_organization
    end
  end
end
