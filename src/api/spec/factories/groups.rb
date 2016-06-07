FactoryGirl.define do
  factory :group do
    sequence(:title){ |n| "group_#{n}" }
    email { Faker::Internet.email }
  end
end
