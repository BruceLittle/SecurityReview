class OrganizationPolicy < ApplicationPolicy
  def index? = true

  def show?
    user.platform_admin? || record.id == user.organization_id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.platform_admin?

      scope.where(id: user.organization_id)
    end
  end
end
