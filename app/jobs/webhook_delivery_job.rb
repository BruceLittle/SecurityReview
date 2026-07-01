require "net/http"
require "json"

class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  class UnsafeDestination < StandardError; end

  def perform(webhook_endpoint_id, event_type, payload)
    endpoint = WebhookEndpoint.find_by(id: webhook_endpoint_id, active: true)
    return if endpoint.nil?

    # Re-validated here, not just at WebhookEndpoint creation time: DNS for
    # a customer-controlled hostname can change between when the endpoint
    # was registered and when we actually connect (classic SSRF-via-
    # rebinding), so the safety check must be the last thing before the
    # network call, not a one-time gate at creation.
    unless WebhookUrlGuard.safe?(endpoint.url)
      raise UnsafeDestination,
            "endpoint #{endpoint.id} no longer resolves to a safe address"
    end

    body = { event: event_type, data: payload, delivered_at: Time.current.iso8601 }.to_json
    deliver(endpoint, body)
  end

  private

  def deliver(endpoint, body)
    uri = URI.parse(endpoint.url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Webhook-Signature"] = endpoint.sign(body)
    request.body = body

    # Net::HTTP never follows redirects unless the caller explicitly
    # re-dispatches a 3xx response — we don't, which closes off
    # redirect-based SSRF against the guard above.
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT,
                                                   read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end

    Rails.logger.info(
      "webhook_delivery organization_id=#{endpoint.organization_id} " \
      "endpoint_id=#{endpoint.id} status=#{response.code}"
    )
    raise "webhook delivery to endpoint #{endpoint.id} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end
end
