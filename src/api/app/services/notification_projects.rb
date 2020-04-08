class NotificationProjects
  attr_reader :notifications

  def initialize(notifications)
    @notifications = notifications
  end

  def call
    notifications.map do |notification|
      notifiable = notification.notifiable

      case notification.notifiable_type
      when 'BsRequest'
        notifiable.target_project_objects.uniq
      when 'Comment'
        case notifiable.commentable_type
        when 'Project'
          [notifiable.commentable]
        when 'Package'
          [notifiable.commentable.project]
        when 'BsRequest'
          notifiable.commentable.target_project_objects.uniq
        end
      when 'Review'
        notifiable.bs_request.target_project_objects.uniq
      end
    end.flatten!
  end
end
