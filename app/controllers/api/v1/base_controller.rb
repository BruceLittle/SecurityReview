module Api
  module V1
    # Every customer-facing API controller inherits from here. Authorization
    # is enforced per-action via Pundit (`authorize` / `policy_scope`) in
    # each controller — this base class only guarantees that, by the time
    # any action body runs, current_organization is a real, active
    # Organization resolved from a verified token, never from a
    # client-supplied id.
    class BaseController < ApplicationController
      include ApiTokenAuthenticatable
      include Auditable

      before_action { use_secure_headers_override(:api) }

      # :index is defined on subclasses, not here — this base class exists
      # precisely to apply one shared Pundit contract across all of them.
      # rubocop:disable Rails/LexicallyScopedActionFilter
      after_action :verify_authorized, except: [:index]
      after_action :verify_policy_scoped, only: [:index]
      # rubocop:enable Rails/LexicallyScopedActionFilter

      PER_PAGE = 25
      MAX_PAGE = 10_000 # generous ceiling to bound OFFSET cost; deep pagination beyond this requires a cursor, not supported here

      private

      # Pundit's "user" for every policy in this controller tree is the
      # authenticated ApiToken, not a Devise user — there is no session
      # user on this branch at all.
      def pundit_user
        current_api_token
      end

      def current_audit_actor
        current_api_token
      end

      def current_audit_organization
        current_organization
      end

      # Bounded, injection-safe pagination for every #index action. `page`
      # is coerced to a positive integer and clamped — never interpolated
      # into SQL, and never allowed to request an unbounded page size.
      def paginate(relation)
        page = params[:page].to_i
        page = 1 if page < 1
        page = MAX_PAGE if page > MAX_PAGE
        relation.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
      end
    end
  end
end
