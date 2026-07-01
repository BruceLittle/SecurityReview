# Two distinct kinds of principal share this table:
#
#   * platform_admin: true, organization_id: nil — internal staff. Full
#     cross-organization access to the /admin console.
#   * platform_admin: false, organization_id: present — a customer-side
#     user with a `role` scoped to *their own* organization only:
#       - "org_admin": may sign into /admin but every query is scoped to
#         their own organization_id (see Admin::BaseController#admin_scope
#         and the Pundit Scope classes).
#       - "member": cannot sign into /admin at all. Customer access to
#         data happens exclusively through the org-scoped ApiToken API.
#
# platform_admin is never mass-assignable (see UsersController strong
# params) and is only ever set directly by another platform_admin through
# the admin console, never via any org-scoped or self-service form.
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable,
         :trackable, :lockable, :timeoutable, :validatable

  belongs_to :organization, optional: true
  has_many :api_tokens, foreign_key: :created_by_user_id, inverse_of: :created_by_user, dependent: :nullify
  has_many :attachments, foreign_key: :uploaded_by_user_id, inverse_of: :uploaded_by_user, dependent: :nullify

  ROLES = %w[member org_admin].freeze

  validates :role, inclusion: { in: ROLES }
  validate :organization_presence_matches_platform_admin

  def platform_admin?
    platform_admin
  end

  def org_admin?
    !platform_admin? && role == "org_admin"
  end

  # Any principal permitted to sign into the internal /admin console at all.
  def staff_access?
    platform_admin? || org_admin?
  end

  private

  def organization_presence_matches_platform_admin
    if platform_admin? && organization_id.present?
      errors.add(:organization_id, "must be blank for platform admins")
    elsif !platform_admin? && organization_id.blank?
      errors.add(:organization_id, "is required for non-platform-admin users")
    end
  end
end
