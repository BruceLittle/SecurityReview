class ApiTokenPolicy < ApplicationPolicy
  def index? = true

  def show?
    user.platform_admin? || record.organization_id == user.organization_id
  end

  def create?
    user.platform_admin? || user.org_admin?
  end

  # Revocation only — plaintext tokens are never retrievable again, so
  # there is no update? action, only create (issue a new one) and
  # destroy (revoke).
  def destroy?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scoped_to_own_organization
    end
  end
end
