FactoryGirl.define do
  factory :repository do
    project
    name { Faker::Internet.domain_word }
  end
end
