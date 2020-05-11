FactoryBot.define do
  factory :notification, class: 'Notification::RssFeedItem' do
    type { 'Notification::RssFeedItem' }
    event_type { 'Event::RequestStatechange' }
    event_payload { { fake: 'payload' } }
    subscription_receiver_role { 'owner' }
    title { Faker::Lorem.sentence }
    delivered { false }

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
      association :notifiable, factory: :user_review
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

  factory :rss_notification, parent: :notification, class: 'Notification::RssFeedItem' do
    rss { true }

    transient do
      stale { false }
    end
    after(:create) do |notification, evaluator|
      if evaluator.stale
        notification.created_at = 6.months.ago
        notification.save
      end
    end
  end

  factory :web_notification, parent: :notification, class: 'Notification::RssFeedItem' do
    web { true }

    transient do
      stale { false }
    end
    after(:create) do |notification, evaluator|
      if evaluator.stale
        notification.created_at = 6.months.ago
        notification.save
      end
    end
  end
end
