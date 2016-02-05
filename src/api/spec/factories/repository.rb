FactoryGirl.define do
  factory :repository do
    project
    name Faker::Lorem.word
  end
end
