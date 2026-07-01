# A customer/tenant. Every domain object (Mission, Inspection, Asset,
# Attachment, ApiToken, WebhookEndpoint) belongs to exactly one Organization
# and must be reached only through it — never through a bare global lookup.
class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :api_tokens, dependent: :destroy
  has_many :missions, dependent: :restrict_with_error
  has_many :inspections, dependent: :restrict_with_error
  has_many :assets, dependent: :restrict_with_error
  has_many :attachments, dependent: :restrict_with_error
  has_many :webhook_endpoints, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :status, inclusion: { in: %w[active suspended] }

  def active?
    status == "active"
  end
end
