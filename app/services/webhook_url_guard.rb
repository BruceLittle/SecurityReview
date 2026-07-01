require "resolv"
require "ipaddr"
require "uri"

# SSRF guard for any customer-supplied outbound URL (currently
# WebhookEndpoint#url). Rejects anything that isn't a public HTTPS host,
# and resolves the hostname to make sure it doesn't land on a private,
# loopback, link-local, or cloud-metadata address — including via DNS
# rebinding, which is why WebhookDeliveryJob re-checks at send time rather
# than trusting the value validated at creation time.
class WebhookUrlGuard
  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.168.0.0/16 198.18.0.0/15
    224.0.0.0/4 240.0.0.0/4 ::1/128 fc00::/7 fe80::/10
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  # The cloud metadata endpoint is also covered by 169.254.0.0/16 above,
  # but is called out explicitly since it's the highest-value SSRF target.
  METADATA_HOST = "169.254.169.254".freeze

  def self.safe?(url)
    new(url).safe?
  end

  def initialize(url)
    @url = url
  end

  def safe?
    uri = parsed_uri
    return false if uri.nil?
    return false unless uri.scheme == "https"
    return false if uri.host.blank?
    return false if uri.host == METADATA_HOST

    addresses = resolved_addresses(uri.host)
    addresses.present? && addresses.all? { |addr| public_address?(addr) }
  rescue Resolv::ResolvError, SocketError
    false
  end

  private

  def parsed_uri
    URI.parse(@url)
  rescue URI::InvalidURIError
    nil
  end

  def resolved_addresses(host)
    Resolv.getaddresses(host).map { |a| IPAddr.new(a) }
  rescue IPAddr::Error
    []
  end

  def public_address?(addr)
    BLOCKED_RANGES.none? { |range| range.include?(addr) }
  end
end
