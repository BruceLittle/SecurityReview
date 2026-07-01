# Base class for the internal /admin console policies (Organization, User,
# ApiToken, AuditLog). `pundit_user` here is a User (see Admin::BaseController)
# that has already passed require_staff_access!, i.e. is either
# platform_admin or org_admin.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = index?
  def create? = false
  # Pundit maps the :new action to its own predicate, not create?, automatically.
  def new? = create?
  def update? = create?
  # Same mapping gap for :edit / update?.
  def edit? = update?
  def destroy? = false

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    # Shared helper: platform_admin sees every row; org_admin/member sees
    # only rows belonging to their own organization. Every concrete Scope
    # below is built from this single primitive rather than reimplementing
    # the platform_admin? branch per resource.
    def scoped_to_own_organization(organization_id_column: :organization_id)
      return scope.all if user.platform_admin?

      scope.where(organization_id_column => user.organization_id)
    end
  end
end
