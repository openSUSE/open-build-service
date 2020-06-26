class NotificationCollector
  def initialize(relation = Notification.all)
    @finder = NotificationsFinder.new(relation)
  end
  
  def review_notifications
    @finder.with_notifiable.where(notifiable_type: 'Review')
  end

  def group_by_review_type
    review_notifications.inject({'submit' => []}) do |acc, n|
      acc[n.event_payload['actions'].first['type']] << n
      acc
    end
  end
end
