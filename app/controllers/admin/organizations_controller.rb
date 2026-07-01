module Admin
  class OrganizationsController < BaseController
    def index
      @organizations = paginate(policy_scope(Organization).order(:name))
    end

    def show
      @organization = policy_scope(Organization).find(params.expect(:id))
      authorize @organization
    end
  end
end
