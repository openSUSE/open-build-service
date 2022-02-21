FactoryBot.define do
  factory :watched_item do
    trait :for_projects do
      watchable { create(:project) }
      user { create(:confirmed_user) }
    end

    trait :for_packages do
      watchable { create(:package) }
      user { create(:confirmed_user) }
    end

    trait :for_bs_requests do
      watchable { create(:bs_request_with_submit_action) }
      user { create(:confirmed_user) }
    end
  end
end
