class SendDailyEmails
  def perform
    notifications = Notification::DailyEmailItem.where(delivered: false).order(created_at: :desc).group_by(&:subscriber)

    notifications.each do  |subscriber, notifications|
      DailyEmailMailer.notifications(subscriber, notifications).deliver_now if notifications.any?

      notifications.each do |notification|
        notification.update_attributes(delivered: true)
      end
    end
  end
end
