module Admin
  class ApiTokensController < BaseController
    def index
      @api_tokens = paginate(policy_scope(ApiToken).order(created_at: :desc))
    end

    def new
      @api_token = ApiToken.new(organization_id: scoped_organization_id)
      authorize @api_token
    end

    def create
      organization = Organization.find(scoped_organization_id)
      @api_token = ApiToken.new(organization: organization)
      authorize @api_token

      result = ApiToken.generate!(
        organization: organization,
        created_by_user: current_user,
        name: token_params[:name],
        ttl: ttl_param
      )

      audit!(
        action: "api_token.create",
        organization: organization,
        auditable: result.record,
        metadata: { name: result.record.name, expires_at: result.record.expires_at }
      )

      # The plaintext token is rendered exactly once, directly in this
      # response — never put into flash/session (which persists beyond
      # this single request) and never written to any log line.
      @plaintext_token = result.plaintext_token
      @api_token = result.record
      render :created
    end

    def destroy
      @api_token = policy_scope(ApiToken).find(params.expect(:id))
      authorize @api_token
      @api_token.revoke!

      audit!(action: "api_token.revoke", auditable: @api_token, organization: @api_token.organization)
      redirect_to admin_api_tokens_path, notice: "Token revoked"
    end

    private

    def scoped_organization_id
      return params.dig(:api_token, :organization_id).presence || current_user.organization_id if current_user.platform_admin?

      current_user.organization_id
    end

    def token_params
      params.expect(api_token: [:name])
    end

    def ttl_param
      days = params.dig(:api_token, :ttl_days).to_i
      days = 90 if days <= 0
      [days.days, ApiToken::MAX_TTL].min
    end
  end
end
