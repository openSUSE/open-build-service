FactoryGirl.define do
  factory :event_subscription do
    factory :event_subscription_comment_for_project do
      eventtype 'Event::CommentForProject'
      receiver_role "commenter"
      channel :instant_email
    end

    factory :event_subscription_request_created do
      eventtype 'Event::RequestCreate'
      receiver_role "all"
      channel :instant_email
    end

    user
  end
end
