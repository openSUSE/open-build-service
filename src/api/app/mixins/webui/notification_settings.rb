require 'event/all'

module Webui::NotificationSettings

  Roles = [:maintainer, :source_maintainer, :target_maintainer, :reviewer, :commenter, :creator]
  Event_types = %w{RequestCreate RequestStatechange CommentForProject CommentForPackage CommentForRequest BuildFail ReviewWanted}

  # find subscribed roles for the user (nil for global settings)
  def notifications_for_user(user)
    @notifications = []

    Event_types.each do |event_type|
      type = 'Event::'+event_type
      display_roles = type.constantize.receiver_roles
      tmp = []
      Roles.each do |role|
        next unless display_roles.include?(role)
        value = EventSubscription.subscription_value(type, role, user)
        tmp << [role, value]
      end
      @notifications << [event_type, type.constantize.description, tmp]
    end

    Rails.logger.debug @notifications.inspect
  end

  # updates settings - user is nil for global
  def update_notifications_for_user(user)
    Event_types.each do |event_type|
      values = params[event_type] || {}
      type = 'Event::'+event_type
      display_roles = type.constantize.receiver_roles
      Roles.each do |role|
        next unless display_roles.include?(role)
        EventSubscription.update_subscription(type, role, user, !values[role].nil?)
      end
    end
  end
end