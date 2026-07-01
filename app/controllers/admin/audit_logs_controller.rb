module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = paginate(policy_scope(AuditLog).order(created_at: :desc))
    end

    def show
      @audit_log = policy_scope(AuditLog).find(params.expect(:id))
      authorize @audit_log
    end
  end
end
