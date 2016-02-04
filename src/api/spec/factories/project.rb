FactoryGirl.define do
  factory :project do
    name Faker::Internet.domain_word
    title Faker::Book.title
  end
end
