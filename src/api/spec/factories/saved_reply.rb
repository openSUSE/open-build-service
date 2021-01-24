FactoryBot.define do
  factory :saved_reply do
    association :user, factory: :user

    title { Faker::Lorem.sentence }
    body  { Faker::Lorem.sentence }
  end
end
