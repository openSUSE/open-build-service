FactoryBot.define do
  factory :configuration do
    name { Faker::Lorem.word }
    title { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
  end
end
