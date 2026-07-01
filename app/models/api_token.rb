require "securerandom"
require "digest"

# A customer-facing API credential, always scoped to exactly one
# Organization. Design constraints (see security review):
#
#   * Only a SHA-256 digest is ever persisted (token_digest). The plaintext
#     value exists only in memory at #generate! time and in the one-time
#     response to the admin who created it — it is never logged, never
#     stored, and cannot be recovered after creation (only reissued).
#   * Every token has a mandatory expiration (default 90 days, capped by
#     MAX_TTL) and can be revoked instantly by setting revoked_at.
#   * Tokens are looked up by digest, not by decrypting/comparing plaintext,
#     and comparison of the *presented* token happens in constant time.
class ApiToken < ApplicationRecord
  MAX_TTL = 1.year
  DEFAULT_TTL = 90.days
  TOKEN_PREFIX = "srv_".freeze # lets ops/log scanners identify a leaked token format

  GenerateResult = Struct.new(:record, :plaintext_token, keyword_init: true)

  belongs_to :organization
  belongs_to :created_by_user, class_name: "User"

  has_many :audit_logs, as: :auditable, dependent: :nullify

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :expires_at_within_max_ttl

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  # Generates a new token, persists only its digest, and returns the
  # plaintext exactly once via the returned struct's #plaintext_token.
  # Callers (Admin::ApiTokensController) must display it once and discard it.
  def self.generate!(organization:, created_by_user:, name:, ttl: DEFAULT_TTL)
    plaintext = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"

    token = create!(
      organization: organization,
      created_by_user: created_by_user,
      name: name,
      token_digest: digest(plaintext),
      expires_at: Time.current + [ttl, MAX_TTL].min
    )

    GenerateResult.new(record: token, plaintext_token: plaintext)
  end

  # Looks up an active, non-revoked, non-expired token by its presented
  # plaintext value. Returns nil for anything else — expired, revoked,
  # unknown, or malformed input never raises, so callers can't leak which
  # failure mode occurred via response timing/behavior differences.
  def self.authenticate(plaintext_token)
    return nil if plaintext_token.blank?

    active.find_by(token_digest: digest(plaintext_token))
  end

  def self.digest(plaintext)
    Digest::SHA256.hexdigest(plaintext)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def record_use!(ip:)
    # update_columns deliberately skips validations/callbacks: this runs on
    # every authenticated request and must not re-validate the whole
    # record (e.g. expires_at_within_max_ttl) just to bump a usage marker.
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(last_used_at: Time.current, last_used_ip: ip)
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def expires_at_within_max_ttl
    return if expires_at.blank?

    return unless expires_at > Time.current + MAX_TTL

    errors.add(:expires_at, "may not exceed #{MAX_TTL.inspect} from now")
  end
end
