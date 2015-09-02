require 'event/all'
# Get/Set notifications. To be used in controllers
module Webui::NotificationSettings
  EVENT_TYPES = [Event::RequestCreate, Event::RequestStatechange,
                 Event::CommentForProject, Event::CommentForPackage,
                 Event::CommentForRequest, Event::BuildFail,
                 Event::ReviewWanted, Event::ServiceFail]

  def notifications_for_user(user = nil)
    result = []

    EVENT_TYPES.each do |event_type|
      display_roles = event_type.receiver_roles.clone
      display_roles.map! do |role|
        [role, EventSubscription.subscription_value(event_type.to_s, role, user)]
      end
      result << [event_type.to_s, event_type.description, display_roles]
    end
    result
  end

  def update_notifications_for_user(user = nil, params)
    EVENT_TYPES.each do |event_type|
      values = params[event_type.to_s] || {}
      display_roles = event_type.receiver_roles
      display_roles.each do |role|
        EventSubscription.update_subscription(event_type.to_s, role, user, !values[role].nil?)
      end
    end
  end
end
