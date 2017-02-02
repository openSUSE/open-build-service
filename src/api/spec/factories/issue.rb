FactoryGirl.define do
  factory :issue do
    name Faker::Lorem.words(5).join(' ')
  end
end
