FactoryBot.define do
  factory :notification do
    event_type { 'Event::RequestStatechange' }
    event_payload { { fake: 'payload' } }
    subscription_receiver_role { 'owner' }
    title { Faker::Lorem.sentence }
    delivered { false }

    trait :stale do
      created_at { 13.months.ago }
    end

    trait :request_state_change do
      event_type { 'Event::RequestStatechange' }
      association :notifiable, factory: :bs_request_with_submit_action
      bs_request_oldstate { :new }
    end

    trait :request_created do
      event_type { 'Event::RequestCreate' }
      association :notifiable, factory: :bs_request_with_submit_action
    end

    trait :review_wanted do
      event_type { 'Event::ReviewWanted' }
      association :notifiable, factory: :bs_request_with_submit_action
    end

    trait :comment_for_project do
      event_type { 'Event::CommentForProject' }
      association :notifiable, factory: :comment_project
    end

    trait :comment_for_package do
      event_type { 'Event::CommentForPackage' }
      association :notifiable, factory: :comment_package
    end

    trait :comment_for_request do
      event_type { 'Event::CommentForRequest' }
      association :notifiable, factory: :comment_request
    end
  end

  factory :rss_notification, parent: :notification do
    rss { true }
  end

  factory :web_notification, parent: :notification do
    web { true }
  end
end
