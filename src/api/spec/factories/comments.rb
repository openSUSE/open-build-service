FactoryBot.define do
  factory :comment do
    body { Faker::Lorem.paragraph }
    user
    parent { nil }

    factory :comment_package do
      commentable { create(:package) }
    end

    factory :comment_project do
      commentable { create(:project) }
    end

    factory :comment_request do
      commentable { create(:set_bugowner_request) }
    end

    trait :bs_request_action do
      association :commentable, factory: :bs_request_with_submit_action
    end
  end
end
