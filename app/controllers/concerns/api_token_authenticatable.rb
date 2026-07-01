# Authenticates the customer-facing JSON API via the `X-Api-Token` header.
#
# Deliberately does NOT fall back to session cookies, HTTP basic auth, or a
# `?token=` query param: query params get logged (access logs, proxies,
# browser history) and a single, explicit header keeps the auth path easy
# to reason about and to rate-limit (see config/initializers/rack_attack.rb).
module ApiTokenAuthenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_api_token

    # protect_from_forgery is for cookie-session requests; this controller
    # tree is exclusively bearer-token authenticated, so CSRF (which relies
    # on the browser silently attaching a cookie) does not apply. This is
    # the one intentional, explicit skip in the app.
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_token!
  end

  def current_organization
    @current_api_token&.organization
  end

  private

  def authenticate_api_token!
    presented_token = request.headers["X-Api-Token"]

    return render_error(status: :unauthorized, message: "Missing X-Api-Token header") if presented_token.blank?

    token = ApiToken.authenticate(presented_token)

    if token.nil?
      AuditLog.record!(action: "api_token.auth_failure", actor: nil, organization: nil, ip_address: request.remote_ip)
      return render_error(status: :unauthorized, message: "Invalid or expired API token")
    end

    return render_error(status: :forbidden, message: "This organization's access is suspended") unless token.organization.active?

    @current_api_token = token
    token.record_use!(ip: request.remote_ip)
  end
end
