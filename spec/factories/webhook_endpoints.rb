FactoryBot.define do
  factory :webhook_endpoint do
    organization
    url { "https://example.com/webhooks/security-review" }
    active { true }

    to_create do |instance|
      created = instance.class.generate!(organization: instance.organization, url: instance.url, active: instance.active)
      instance.id = created.id
    end
  end
end
