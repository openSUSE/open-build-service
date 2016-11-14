FactoryGirl.define do
  factory :comment_request do
    body { Faker::Lorem.paragraph }
    user
    bs_request
  end
end
