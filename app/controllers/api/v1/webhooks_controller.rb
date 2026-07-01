module Api
  module V1
    # Receives the third-party scanner's asynchronous result callback.
    # Deliberately NOT under Api::V1::BaseController: this is a
    # system-to-system callback with no per-organization ApiToken, so it is
    # authenticated purely by a shared HMAC secret over the raw request
    # body, verified in constant time.
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token

      VALID_RESULTS = %w[clean malicious].freeze

      def scan_results
        return render_error(status: :unauthorized, message: "Invalid signature") unless valid_signature?

        attachment = Attachment.find_by(external_reference_id: scan_params[:external_reference_id])
        return render_error(status: :not_found, message: "Unknown reference") if attachment.nil?

        unless VALID_RESULTS.include?(scan_params[:result])
          return render_error(status: :bad_request, message: "Unrecognized result")
        end

        apply_scan_result(attachment, scan_params[:result])

        head :no_content
      end

      private

      def apply_scan_result(attachment, result)
        case result
        when "clean"
          attachment.mark_processed!
        when "malicious"
          attachment.quarantine!
        end

        WebhookNotifier.notify(attachment.organization, "attachment.#{attachment.status}",
                               { attachment_id: attachment.id, asset_id: attachment.asset_id })

        AuditLog.record!(
          action: "attachment.scan_result",
          actor: nil, # actor_type defaults to "System" — this is a trusted server-to-server callback, not a user/token action
          organization: attachment.organization,
          auditable: attachment,
          ip_address: request.remote_ip,
          metadata: { result: result }
        )
      end

      # HMAC-SHA256 over the exact raw request body (not the
      # Rails-reparsed params, which could diverge from what was actually
      # signed) using a secret shared out-of-band with the vendor —
      # compared in constant time to avoid a timing side-channel.
      def valid_signature?
        secret = ENV.fetch("SCAN_WEBHOOK_SIGNING_SECRET")
        presented = request.headers["X-Vendor-Signature"]
        return false if presented.blank?

        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)
        ActiveSupport::SecurityUtils.secure_compare(presented, expected)
      end

      def scan_params
        params.permit(:external_reference_id, :result)
      end
    end
  end
end
