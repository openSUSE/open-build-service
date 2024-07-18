FactoryBot.define do
  factory :canned_response do
    title { Faker::Lorem.word }
    content { Faker::Lorem.paragraph }
    user { association :confirmed_user }

    factory :cleared_canned_response do
      decision_type { 'cleared' }
      user { association :moderator }
    end
    factory :favored_canned_response do
      decision_type { 'favored' }
      user { association :moderator }
    end
  end
end
