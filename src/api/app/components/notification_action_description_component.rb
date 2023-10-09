class NotificationActionDescriptionComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
    @role = @notification.event_payload['role']
    @user = @notification.event_payload['who']
    # If a notification is for a group, the notified user needs to know for which group. Otherwise, the user is simply referred to as 'you'.
    @recipient = @notification.event_payload.fetch('group', 'you')
    project = @notification.event_payload['project']
    package = @notification.event_payload['package']
    @target_object = [project, package].compact.join(' / ')
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def call
    tag.div(class: ['smart-overflow']) do
      case @notification.event_type
      when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted', 'Event::CommentForRequest'
        BsRequestActionSourceAndTargetComponent.new(bs_request).call
      when 'Event::CommentForProject'
        "#{@notification.notifiable.commentable.name}"
      when 'Event::CommentForPackage'
        commentable = @notification.notifiable.commentable
        "#{commentable.project.name} / #{commentable.name}"
      when 'Event::RelationshipCreate'
        "#{@user} made #{@recipient} #{@role} of #{@target_object}"
      when 'Event::RelationshipDelete'
        "#{@user} removed #{@recipient} as #{@role} of #{@target_object}"
      when 'Event::BuildFail'
        "Build was triggered because of #{@notification.event_payload['reason']}"
      when 'Event::ReportForProject', 'Event::ReportForPackage', 'Event::ReportForComment', 'Event::ReportForUser'
        "'#{@notification.notifiable.user.login}' created a report for a #{@notification.event_payload['reportable_type'].downcase}. This is the reason:"
      when 'Event::ClearedDecision'
        class_name = @notification.notifiable.reports.first.reportable.class.name.downcase
        "'#{@notification.notifiable.moderator.login}' decided to clear the report about the #{class_name}. This is the reason:"
      when 'Event::FavoredDecision'
        class_name = @notification.notifiable.reports.first.reportable.class.name.downcase
        "'#{@notification.notifiable.moderator.login}' decided to favor the report about the #{class_name}. This is the reason:"
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def bs_request
    @bs_request ||= if @notification.notifiable_type == 'BsRequest'
                      @notification.notifiable
                    elsif @notification.notifiable.commentable.is_a?(BsRequestAction)
                      @notification.notifiable.commentable.bs_request
                    else
                      @notification.notifiable.commentable
                    end
  end
end
