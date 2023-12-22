class Decorators::Notification::Event::RequestCreate < Decorators::Notification::Common
  def description_text
    bs_request = notification.notifiable
    BsRequestActionSourceAndTargetComponent.new(bs_request).call
  end

  def notifiable_link_text(helpers)
    "#{helpers.request_type_of_action(notification.notifiable)} Request ##{notification.notifiable.number}"
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.request_show_path(notification.notifiable.number, notification_id: notification.id)
  end

  def avatar_objects
    reviews = notification.notifiable.reviews
    reviews.select(&:new?).map(&:reviewed_by) + User.where(login: notification.notifiable.creator)
  end
end
