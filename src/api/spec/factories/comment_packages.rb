FactoryGirl.define do
  factory :comment_package do
    body { Faker::Lorem.paragraph }
    user
    package
  end
end
