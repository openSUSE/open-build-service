FactoryBot.define do
  factory :notification do
    event_type { 'FakeEventType' }
    event_payload { { fake: 'payload' } }
    subscription_receiver_role { 'owner' }
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
