FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "correct-horse-battery-staple" }
    role { "member" }
    platform_admin { false }
    organization

    trait :platform_admin do
      platform_admin { true }
      organization { nil }
      role { "member" }
    end

    trait :org_admin do
      role { "org_admin" }
    end
  end
end
