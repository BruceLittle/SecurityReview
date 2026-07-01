module Api
  module V1
    class AssetsController < BaseController
      def show
        asset = policy_scope(Asset).find(params.expect(:id))
        authorize asset
        render json: asset.as_json(only: %i[id inspection_id asset_type identifier created_at updated_at])
      end
    end
  end
end
