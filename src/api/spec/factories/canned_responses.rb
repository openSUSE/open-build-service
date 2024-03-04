FactoryBot.define do
  factory :canned_response do
    title { Faker::Lorem.word }
    content { Faker::Lorem.paragraph }
    user { association :confirmed_user }

    factory :cleared_canned_response do
      decision_kind { 'cleared' }
      user { association :moderator }
    end
    factory :favor_canned_response do
      decision_kind { 'favor' }
      user { association :moderator }
    end
  end
end
