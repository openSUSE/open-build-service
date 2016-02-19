FactoryGirl.define do
  factory :group do
    title { Faker::Internet.user_name(nil, %w(. -))  }
    email { Faker::Internet.email }
  end
end
