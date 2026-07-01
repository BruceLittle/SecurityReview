# Fans an event out to every active WebhookEndpoint registered by the
# given organization. Each delivery is its own job — one slow or failing
# customer endpoint never blocks delivery to another endpoint or another
# organization.
class WebhookNotifier
  def self.notify(organization, event_type, payload)
    organization.webhook_endpoints.where(active: true).find_each do |endpoint|
      WebhookDeliveryJob.perform_later(endpoint.id, event_type, payload)
    end
  end
end
