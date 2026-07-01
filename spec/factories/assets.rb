FactoryBot.define do
  factory :asset do
    inspection
    asset_type { "roof" }
    sequence(:identifier) { |n| "asset-#{n}" }
  end
end
