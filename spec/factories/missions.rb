FactoryBot.define do
  factory :mission do
    organization
    sequence(:name) { |n| "Mission #{n}" }
    status { "scheduled" }

    trait :archived do
      status { "archived" }
      archived_at { Time.current }
    end
  end
end
