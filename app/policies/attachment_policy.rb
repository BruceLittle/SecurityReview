# Authorization for attachment metadata (#show) and presigned-URL
# generation (#download). Both reduce to the same org-scoping check;
# *business*-state gates (quarantined, archived, deleted -> not
# downloadable) are deliberately handled separately in
# Api::V1::AttachmentsController, not folded into this policy, so an
# authorization failure and a "this file isn't available" response are
# never conflated in logs or in the response the caller sees.
class AttachmentPolicy < TokenScopedPolicy
  def download?
    same_organization?
  end

  class Scope < TokenScopedPolicy::Scope
    def resolve
      super.not_deleted
    end
  end
end
