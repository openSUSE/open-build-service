class NotifiedProjects
  def initialize(notification)
    @notification = notification
    @notifiable = @notification.notifiable
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def call
    return Project.none if @notifiable.blank?

    case @notification.notifiable_type
    when 'BsRequest'
      @notifiable.target_project_objects.distinct
    when 'Comment'
      case @notifiable.commentable_type
      when 'Project'
        [@notifiable.commentable]
      when 'Package'
        [@notifiable.commentable.project]
      when 'BsRequest'
        @notifiable.commentable.target_project_objects.distinct
      when 'BsRequestAction'
        @notifiable.commentable.bs_request.target_project_objects.distinct
      end
    when 'Package'
      [@notifiable.project]
    when 'Project'
      [@notifiable]
    when 'Report', 'Decision', 'Appeal', 'WorkflowRun', 'Group'
      []
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
