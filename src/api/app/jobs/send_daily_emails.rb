class SendDailyEmails
  def perform
    user_notifications = Notifications::DailyEmailItem.where(group: nil, delivered: false).order(created_at: :desc).group_by(&:user)

    user_notifications.each do  |user, notifications|
      DailyEmailMailer.notifications(user, notifications).deliver_now if notifications.any?
      notifications.each do |notification|
        notification.update_attributes(delivered: true)
      end
    end
  end
end
