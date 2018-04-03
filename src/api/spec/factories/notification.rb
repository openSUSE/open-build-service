FactoryBot.define do
  factory :notification do
    event_type 'FakeEventType'
    event_payload(fake: 'payload')
    subscription_receiver_role 'owner'
  end

  factory :rss_notification, parent: :notification, class: 'Notification::RssFeedItem' do
  end
end
