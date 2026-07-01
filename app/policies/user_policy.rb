class UserPolicy < ApplicationPolicy
  def index? = true

  def show?
    user.platform_admin? || record.organization_id == user.organization_id
  end

  def create?
    user.platform_admin? || user.org_admin?
  end

  def update?
    return false if record.platform_admin? && !user.platform_admin?

    show?
  end

  def destroy?
    return false if record.id == user.id # can't remove your own access
    return false if record.platform_admin? && !user.platform_admin?

    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scoped_to_own_organization
    end
  end
end
