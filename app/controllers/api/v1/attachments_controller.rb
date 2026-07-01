module Api
  module V1
    class AttachmentsController < BaseController
      def show
        attachment = policy_scope(Attachment).find(params.expect(:id))
        authorize attachment
        render json: attachment.as_json(only: %i[id asset_id content_type byte_size status created_at updated_at])
      end

      # Initiates an upload: the asset must belong to the caller's
      # organization (checked via policy_scope + authorize, same pattern as
      # every other lookup in this controller tree), then a pending
      # Attachment row is created with a server-generated s3_key — the
      # client never supplies or influences the key — and a short-lived
      # presigned PUT URL is returned for the client to upload directly to
      # S3. AttachmentProcessingJob then asks the vendor scanner to inspect
      # the object once it lands; WebhooksController#scan_results receives
      # the result and flips status to processed/quarantined.
      def create
        asset = policy_scope(Asset).find(params.expect(:asset_id))
        authorize asset, :show? # org-ownership check; there is no separate create? predicate for assets

        attachment = asset.attachments.create!(attachment_params.merge(uploaded_by_user: nil))
        presigned = S3PresignedUrlService.new(attachment).presigned_put_url

        AttachmentProcessingJob.perform_later(attachment.id)
        audit!(action: "attachment.upload_initiated", auditable: attachment)

        render json: {
          attachment_id: attachment.id,
          upload_url: presigned.url,
          upload_url_expires_at: presigned.expires_at
        }, status: :created
      end

      # Generates a short-lived S3 presigned GET URL. Order of operations
      # matters and is deliberately linear and unskippable:
      #   1. Resolve the record through an org-scoped query (policy_scope).
      #   2. `authorize` again, explicitly, for the :download? action.
      #   3. Check business-level availability (not quarantined/archived/deleted).
      #   4. Only then ask S3PresignedUrlService for a URL.
      #   5. Audit-log the access (object id, actor, org, ip — never the URL).
      # There is no path from "id" to "S3 URL" that skips steps 1-3.
      def download
        attachment = policy_scope(Attachment).find(params.expect(:id))
        authorize attachment, :download?

        unless attachment.downloadable?
          return render_error(status: :conflict, message: "This attachment is not available for download")
        end

        presigned = S3PresignedUrlService.new(attachment).presigned_get_url

        audit!(action: "attachment.download", auditable: attachment, metadata: { expires_at: presigned.expires_at })

        render json: { url: presigned.url, expires_at: presigned.expires_at }
      end

      private

      # Deliberately only content_type is client-settable. organization_id,
      # asset association, s3_key, status, and external_reference_id are
      # all derived server-side (see Attachment callbacks) — none of them
      # can be influenced by request params, which is what prevents mass
      # assignment into another organization's asset or a forged s3_key.
      def attachment_params
        params.expect(attachment: [:content_type])
      end
    end
  end
end
