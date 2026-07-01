# Base class for every policy backing the customer-facing, ApiToken-
# authenticated JSON API (Mission, Inspection, Asset, Attachment). The
# `pundit_user` here is always the *ApiToken*, never a User — see
# Api::V1::BaseController#pundit_user. Every subclass decision reduces to
# a single question: does record.organization_id match token.organization_id?
#
# This is enforced at the policy layer (not ad hoc in each controller) so
# there is exactly one place per resource where org-scoping can be gotten
# wrong, and it is covered directly by the regression suite in
# spec/policies/.
class TokenScopedPolicy
  attr_reader :token, :record

  def initialize(token, record)
    @token = token
    @record = record
  end

  def show?
    same_organization?
  end

  private

  def same_organization?
    token.present? && record.present? && record.organization_id == token.organization_id
  end

  class Scope
    attr_reader :token, :scope

    def initialize(token, scope)
      @token = token
      @scope = scope
    end

    def resolve
      scope.where(organization_id: token.organization_id)
    end
  end
end
