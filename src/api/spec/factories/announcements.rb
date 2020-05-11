FactoryBot.define do
  factory :announcement do
    title { Faker::Book.title }
    content { Faker::Lorem.sentence }
  end
end
