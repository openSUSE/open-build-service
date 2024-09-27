FactoryBot.define do
  factory :watched_item do
    trait :for_projects do
      watchable { association :project }
      user { association :confirmed_user }
    end

    trait :for_packages do
      watchable { association :package }
      user { association :confirmed_user }
    end

    trait :for_bs_requests do
      watchable { association :bs_request_with_submit_action }
      user { association :confirmed_user }
    end
  end
end
