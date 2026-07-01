FactoryBot.define do
  factory :attachment do
    asset
    content_type { "image/jpeg" }
    byte_size { 123_456 }
    status { "processed" }

    trait :pending do
      status { "pending" }
    end

    trait :quarantined do
      status { "quarantined" }
    end

    trait :archived do
      archived_at { Time.current }
    end

    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
