require "net/http"
require "json"

# Talks to the third-party file-scanning vendor. Unlike WebhookEndpoint#url
# (customer-supplied, needs SSRF guarding), this endpoint is a single,
# ops-configured value from ENV — never influenced by request params — so
# there is no SSRF surface here.
class ScanVendorClient
  class Error < StandardError; end

  def initialize(base_url: ENV.fetch("SCAN_VENDOR_API_URL"), api_key: ENV.fetch("SCAN_VENDOR_API_KEY"))
    @base_url = base_url
    @api_key = api_key
  end

  # Asks the vendor to scan the object at the given S3 key once uploaded.
  # The vendor calls back asynchronously to
  # POST /api/v1/webhooks/scan_results with external_reference_id,
  # authenticated by SCAN_WEBHOOK_SIGNING_SECRET (see WebhooksController).
  def request_scan(attachment)
    uri = URI.join(@base_url, "/v1/scan-requests")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      external_reference_id: attachment.external_reference_id,
      s3_bucket: ENV.fetch("S3_ATTACHMENTS_BUCKET"),
      s3_key: attachment.s3_key,
      content_type: attachment.content_type
    }.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end

    raise Error, "scan vendor returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response
  end
end
