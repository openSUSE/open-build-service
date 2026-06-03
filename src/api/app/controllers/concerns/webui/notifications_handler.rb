module Webui::NotificationsHandler
  extend ActiveSupport::Concern

  included do
    helper_method :notification_target_path_with_return_to, :notification_return_to_path, :notification_context_params
  end

  def handle_notification
    return unless User.session && params[:notification_id]

    current_notification = Notification.find(params[:notification_id])

    return unless NotificationPolicy.new(User.session, current_notification).update?

    current_notification
  end

  private

  def notification_target_path_with_return_to(path)
    uri = URI.parse(path)
    return_to_query = { return_to: request.fullpath }.to_query
    uri.query = [uri.query, return_to_query].compact_blank.join('&')
    uri.to_s
  rescue URI::InvalidURIError
    path
  end

  def notification_return_to_path
    uri = URI.parse(params[:return_to].to_s)

    return my_notifications_path if uri.scheme.present? || uri.host.present?
    return my_notifications_path unless uri.path == my_notifications_path

    uri.to_s
  rescue URI::InvalidURIError
    my_notifications_path
  end

  def notification_context_params
    {
      notification_id: params[:notification_id],
      return_to: params[:return_to]
    }.compact
  end
end
