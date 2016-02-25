FactoryGirl.define do
  factory :group do
    sequence(:title){|n| "#{Faker::Internet.user_name(nil, %w(_))}#{n}" }
    email { Faker::Internet.email }
  end
end
