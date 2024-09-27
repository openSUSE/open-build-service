module Webui::NotificationsHandler
  extend ActiveSupport::Concern

  def handle_notification
    return unless User.session && params[:notification_id]

    current_notification = Notification.find(params[:notification_id])

    return unless NotificationCommentPolicy.new(User.session, current_notification).update?

    current_notification
  end
end
