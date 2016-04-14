FactoryGirl.define do
  factory :package do
    sequence(:name) { |n| "#{Faker::Internet.domain_word}#{n}" }
  end
end
