FactoryGirl.define do
  factory :comment_project do
    body { Faker::Lorem.paragraph }
    user
    project
  end
end
