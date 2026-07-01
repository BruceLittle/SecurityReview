module Api
  module V1
    class InspectionsController < BaseController
      # Nested under /missions/:mission_id/inspections as well as reachable
      # directly at /inspections/:id — both paths resolve the mission (if
      # any) and the inspection through the SAME org-scoped query.
      def index
        # org-ownership check; Pundit would otherwise look for the
        # nonexistent Mission#index? predicate for this controller action.
        mission = policy_scope(Mission).find(params.expect(:mission_id))
        authorize mission, :show?

        inspections = paginate(mission.inspections.not_archived.order(created_at: :desc))
        render json: inspections.as_json(only: %i[id status scheduled_at completed_at created_at updated_at])
      end

      def show
        inspection = policy_scope(Inspection).find(params.expect(:id))
        authorize inspection
        render json: inspection.as_json(only: %i[id mission_id status scheduled_at completed_at created_at updated_at])
      end
    end
  end
end
