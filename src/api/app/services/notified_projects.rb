class NotifiedProjects
  def initialize(notification)
    @notification = notification
    @notifiable = @notification.notifiable
  end

  def call
    return Project.none if @notifiable.blank?

    case @notification.notifiable_type
    when 'BsRequest'
      @notifiable.target_project_objects.distinct
    when 'Comment'
      case @notifiable.commentable_type
      when 'Project'
        @notifiable.commentable
      when 'Package'
        @notifiable.commentable.project
      when 'BsRequest'
        @notifiable.commentable.target_project_objects.distinct
      end
    end
  end
end
