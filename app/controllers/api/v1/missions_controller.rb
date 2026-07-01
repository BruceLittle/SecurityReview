module Api
  module V1
    class MissionsController < BaseController
      def index
        missions = paginate(policy_scope(Mission).not_archived.order(created_at: :desc))
        render json: missions.as_json(only: %i[id name status created_at updated_at])
      end

      def show
        # The WHERE clause is built from policy_scope (organization_id =
        # token.organization_id) BEFORE the id lookup runs — a mission
        # belonging to another organization simply does not exist in this
        # query, so a cross-org id 404s instead of leaking existence via a
        # 403. `authorize` below is defense-in-depth on top of that, and is
        # what satisfies verify_authorized.
        mission = policy_scope(Mission).find(params.expect(:id))
        authorize mission
        render json: mission.as_json(only: %i[id name status created_at updated_at])
      end
    end
  end
end
