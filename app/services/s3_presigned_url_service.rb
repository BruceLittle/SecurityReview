require "aws-sdk-s3"

# The ONLY place in the app that talks to Aws::S3::Presigner. Every caller
# must hand this service an Attachment record that has *already* passed
# through Pundit authorization (org-scoping) in the controller — this
# class does not know about the current request, the caller's identity, or
# any client-supplied id, and cannot be reached with a bare id/key.
#
# As defense-in-depth against a future caller that forgets the
# authorization/availability check, #presigned_get_url still refuses to
# generate a URL for an attachment that isn't Attachment#downloadable? —
# it fails closed rather than trusting the caller unconditionally.
class S3PresignedUrlService
  GET_EXPIRES_IN = 5.minutes.to_i   # downloads are viewed promptly; short-lived on purpose
  PUT_EXPIRES_IN = 15.minutes.to_i  # uploads may be slower (large files), still bounded

  PresignedUrl = Struct.new(:url, :expires_at, keyword_init: true)

  class NotDownloadable < StandardError; end

  def initialize(attachment, s3_client: nil)
    @attachment = attachment
    @s3_client = s3_client || Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "us-east-1"))
  end

  def presigned_get_url
    raise NotDownloadable, "attachment #{@attachment.id} is not downloadable" unless @attachment.downloadable?

    signer = Aws::S3::Presigner.new(client: @s3_client)
    url, = signer.presigned_request(
      :get_object,
      bucket: bucket_name,
      key: @attachment.s3_key,
      expires_in: GET_EXPIRES_IN
    )

    log_presign_event(action: "get")
    PresignedUrl.new(url: url, expires_at: Time.current + GET_EXPIRES_IN)
  end

  def presigned_put_url
    signer = Aws::S3::Presigner.new(client: @s3_client)
    url, = signer.presigned_request(
      :put_object,
      bucket: bucket_name,
      key: @attachment.s3_key,
      content_type: @attachment.content_type,
      expires_in: PUT_EXPIRES_IN
    )

    log_presign_event(action: "put")
    PresignedUrl.new(url: url, expires_at: Time.current + PUT_EXPIRES_IN)
  end

  private

  def bucket_name
    ENV.fetch("S3_ATTACHMENTS_BUCKET")
  end

  # Logs that a URL was minted — attachment id, organization, action, key,
  # expiry — but never the URL itself, which embeds the request signature
  # (AWS SigV4 query-string auth). Logging the signature would let anyone
  # with log access use the URL for its full validity window.
  def log_presign_event(action:)
    Rails.logger.info(
      "s3_presign action=#{action} attachment_id=#{@attachment.id} " \
      "organization_id=#{@attachment.organization_id} bucket=#{bucket_name} " \
      "expires_in=#{action == 'get' ? GET_EXPIRES_IN : PUT_EXPIRES_IN}"
    )
  end
end
