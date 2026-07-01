module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show edit update destroy]

    def index
      @users = paginate(policy_scope(User).order(:email))
    end

    def show
      authorize @user
    end

    def new
      @user = User.new(organization_id: scoped_organization_id)
      authorize @user
    end

    def edit
      authorize @user
    end

    def create
      @user = User.new(user_params)
      # organization_id is never taken from params: an org_admin can only
      # ever create users in their own org, and platform_admin status can
      # only ever be granted by an existing platform_admin, via a distinct
      # field that is itself never permitted through user_params.
      @user.organization_id = scoped_organization_id
      @user.platform_admin = false
      authorize @user

      if @user.save
        audit!(action: "user.create", auditable: @user, organization: @user.organization)
        redirect_to admin_user_path(@user), notice: "User created"
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user

      if @user.update(user_params)
        audit!(action: "user.update", auditable: @user, organization: @user.organization)
        redirect_to admin_user_path(@user), notice: "User updated"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @user
      @user.destroy!
      audit!(action: "user.destroy", auditable: @user, organization: @user.organization)
      redirect_to admin_users_path, notice: "User removed"
    end

    private

    def set_user
      @user = policy_scope(User).find(params.expect(:id))
    end

    # Only a platform_admin may pick an arbitrary organization; an org_admin
    # is pinned to their own, regardless of what (if anything) is submitted.
    def scoped_organization_id
      return params.dig(:user, :organization_id).presence || current_user.organization_id if current_user.platform_admin?

      current_user.organization_id
    end

    # platform_admin is deliberately absent from this list — it is not
    # mass-assignable under any role. See #create/#update for how it is set.
    def user_params
      params.expect(user: %i[email password password_confirmation role])
    end
  end
end
