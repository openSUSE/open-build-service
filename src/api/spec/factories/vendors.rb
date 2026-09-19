FactoryBot.define do
  factory :vendor do
    name { Faker::Company.name }
    description { Faker::Lorem.sentence }
    url { Faker::Internet.url }
    project
  end
end
