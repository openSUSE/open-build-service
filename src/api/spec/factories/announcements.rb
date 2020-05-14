FactoryBot.define do
  factory :announcement do
    message { Faker::Lorem.sentence }
  end
end
