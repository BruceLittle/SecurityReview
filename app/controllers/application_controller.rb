class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # CSRF protection applies to the session-authenticated admin panel; the
  # token-authenticated JSON API is exempted explicitly in
  # Api::V1::BaseController (never here, so nothing falls through by
  # omission).
  protect_from_forgery with: :exception

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  # Belt-and-suspenders: config.action_dispatch.show_exceptions is :none in
  # production, but this guarantees no stack trace or internal detail ever
  # reaches a client even if that config is ever weakened.
  unless Rails.env.local?
    rescue_from StandardError do |exception|
      Rails.logger.error("Unhandled #{exception.class}: #{exception.message}")
      render_error(status: :internal_server_error, message: "Something went wrong")
    end
  end

  private

  def render_forbidden
    render_error(status: :forbidden, message: "You are not authorized to perform this action")
  end

  def render_not_found
    render_error(status: :not_found, message: "Not found")
  end

  def render_bad_request(exception)
    render_error(status: :bad_request, message: exception.message)
  end

  def render_error(status:, message:)
    respond_to do |format|
      format.json { render json: { error: message }, status: status }
      format.html { render plain: message, status: status }
    end
  end
end
