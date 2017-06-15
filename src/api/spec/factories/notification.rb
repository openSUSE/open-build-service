FactoryGirl.define do
  factory :notification, class: 'Notifications::Base' do
    event_type 'FakeEventType'
    event_payload 'FakeJsonPayload'
    subscription_receiver_role 'owner'
  end

  factory :rss_notification, parent: :notification, class: 'Notifications::RssFeedItem' do
  end
end
