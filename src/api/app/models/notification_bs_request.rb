class NotificationBsRequest < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    "#{request_type_of_action(notifiable)} Request ##{notifiable.number}"
  end

  def description
    "From #{request_source} to #{request_target}"
  end

  def excerpt
    notifiable.description.to_s # description can be nil
  end

  def involved_users
    reviews = notifiable.reviews
    reviews.select(&:new?).map(&:reviewed_by) + User.where(login: notifiable.creator)
  end
end