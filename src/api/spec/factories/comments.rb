FactoryBot.define do
  factory :comment do
    body { Faker::Lorem.paragraph }
    user
    parent { nil }

    factory :comment_package do
      commentable { association :package }
    end

    factory :comment_project do
      commentable { association :project }
    end

    factory :comment_request do
      commentable { association :set_bugowner_request }
    end

    factory :comment_report do
      commentable { association :report }
    end

    trait :bs_request_action do
      commentable factory: [:bs_request_with_submit_action]
    end
  end
end
