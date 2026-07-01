module Admin
  # Internal administrative console. Session-authenticated only (Devise) —
  # this controller tree is never reachable via X-Api-Token, and an
  # X-Api-Token header on a request here has no effect at all, since
  # ApiTokenAuthenticatable is never included in this branch of the
  # controller hierarchy.
  #
  # Two distinct principals can reach here (see User model comment):
  #   * platform_admin — full cross-organization access.
  #   * org_admin       — access restricted to their own organization via
  #                        Pundit's Scope classes (never the platform-wide
  #                        query); enforced in every controller action, not
  #                        just at the menu/routing level.
  class BaseController < ApplicationController
    include Pundit::Authorization
    include Auditable

    before_action :authenticate_user!
    before_action :require_staff_access!

    # :index is defined on subclasses, not here — see the identical note in
    # Api::V1::BaseController.
    # rubocop:disable Rails/LexicallyScopedActionFilter
    after_action :verify_authorized, except: [:index]
    after_action :verify_policy_scoped, only: [:index]
    # rubocop:enable Rails/LexicallyScopedActionFilter

    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

    PER_PAGE = 50
    MAX_PAGE = 10_000

    private

    def paginate(relation)
      page = params[:page].to_i
      page = 1 if page < 1
      page = MAX_PAGE if page > MAX_PAGE
      relation.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    end

    def current_audit_actor
      current_user
    end

    def current_audit_organization
      current_user&.organization
    end

    def require_staff_access!
      return if current_user.staff_access?

      audit!(action: "admin.access_denied")
      render_error(status: :forbidden, message: "You do not have access to the admin console")
    end
  end
end
