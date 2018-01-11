FactoryBot.define do
  factory :notification do
    event_type 'Event::CommentForProject'
    event_payload { {} }
    subscription_receiver_role 'owner'

    initialize_with { new(attributes) }
  end

  factory :rss_notification, parent: :notification, class: 'Notification::RssFeedItem' do
  end
end
