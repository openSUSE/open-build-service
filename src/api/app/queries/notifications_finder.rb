class NotificationsFinder
  def initialize(relation = Notification.all)
    @relation = relation.order(created_at: :desc)
  end

  def read
    @relation.where(delivered: true)
  end

  def unread
    @relation.where(delivered: false)
  end

  def with_notifiable
    @relation.where.not(notifiable_id: nil).where.not(notifiable_type: nil)
  end

  def without_notifiable
    @relation.where(notifiable_id: nil, notifiable_type: nil)
  end

  def for_subscribed_user(user = User.session)
    @relation.where("(subscriber_type = 'User' AND subscriber_id = ?) OR (subscriber_type = 'Group' AND subscriber_id IN (?))",
                    user, user.groups.map(&:id))
  end

  def for_notifiable_type(type = 'unread')
    notifications = self.class.new(with_notifiable)

    case type
    when 'read'
      notifications.read
    when 'comments'
      notifications.unread.where(notifiable_type: 'Comment')
    when 'requests'
      notifications.unread.where(notifiable_type: 'BsRequest')
    else
      notifications.unread
    end
  end

  def for_project_name(project_name)
    unread.joins(:projects).where(projects: { name: project_name })
  end

  def for_subscribed_user_by_id(notification_id)
    return unless User.session && notification_id

    self.class.new.for_subscribed_user.find_by(id: notification_id)
  end
end
