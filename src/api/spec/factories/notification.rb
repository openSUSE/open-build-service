FactoryBot.define do
  factory :notification do
    type { 'Notification' }
    event_type { 'FakeEventType' }
    event_payload { { fake: 'payload' } }
    subscription_receiver_role { 'owner' }
    title { Faker::Lorem.sentence }
    delivered { false }

    trait :state_change do
      event_type { 'Event::StateChange' }
      association :notifiable, factory: :bs_request_with_submit_action
      bs_request_oldstate { :new }
    end

    trait :creation do
      event_type { 'Event::RequestCreated' }
      association :notifiable, factory: :bs_request_with_submit_action
    end

    trait :review do
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

  factory :rss_notification, parent: :notification, class: 'Notification::RssFeedItem' do
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
