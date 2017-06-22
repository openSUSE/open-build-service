FactoryGirl.define do
  factory :event_subscription do
    factory :event_subscription_comment_for_project do
      eventtype 'Event::CommentForProject'
      receiver_role "commenter"
      channel :instant_email
    end

    user
  end
end
