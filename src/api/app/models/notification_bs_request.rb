class NotificationBsRequest < Notification
  include NotificationRequest

  def description
    return "To #{request_target}" if request_source.blank?

    "From #{request_source} to #{request_target}"
  end

  def excerpt
    notifiable.description
  end

  def avatar_objects
    reviews = notifiable.reviews
    reviews.select(&:new?).map(&:reviewed_by) + User.where(login: notifiable.creator).compact
  end

  def link_text
    "#{request_type_of_action} Request ##{notifiable.number}"
  end

  def link_path
    Rails.application.routes.url_helpers.request_show_path(notifiable.number, notification_id: id)
  end

  def bs_request
    notifiable
  end
end
