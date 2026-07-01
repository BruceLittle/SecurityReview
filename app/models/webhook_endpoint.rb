# An organization-registered HTTPS endpoint that receives outbound event
# deliveries (see Jobs::WebhookDeliveryJob). Because the URL is supplied by
# the customer, it is validated against SSRF at creation time AND
# re-validated immediately before every delivery (DNS can change between
# the two) — see WebhookUrlGuard.
class WebhookEndpoint < ApplicationRecord
  belongs_to :organization

  # Encrypted at rest (ActiveRecord::Encryption) using the app's primary
  # encryption key from Rails credentials, never a value derived from
  # application source. Decrypted transparently in-process only when
  # WebhookDeliveryJob needs to compute a delivery signature.
  encrypts :signing_secret

  validates :url, presence: true
  validates :signing_secret, presence: true
  validate :url_is_safe_https_destination

  def self.generate!(**attrs)
    create!(**attrs, signing_secret: SecureRandom.urlsafe_base64(32))
  end

  def sign(payload)
    OpenSSL::HMAC.hexdigest("SHA256", signing_secret, payload)
  end

  private

  def url_is_safe_https_destination
    return if url.blank?

    return if WebhookUrlGuard.safe?(url)

    errors.add(:url, "must be a public HTTPS URL that does not resolve to a private/internal address")
  end
end
