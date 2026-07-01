FactoryBot.define do
  factory :inspection do
    mission
    status { "scheduled" }

    trait :archived do
      status { "archived" }
      archived_at { Time.current }
    end
  end
end
