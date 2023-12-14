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

  def call
    tag.div(description_text, class: ['smart-overflow'])
  end

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

  # rubocop:disable Metrics/CyclomaticComplexity
  def description_text
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
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport', 'Event::ReportForProject', 'Event::ReportForPackage', 'Event::ReportForUser'
      "'#{@notification.notifiable.user.login}' created a report for a #{@notification.event_payload['reportable_type'].downcase}. This is the reason:"
    when 'Event::ReportForRequest'
      "'#{@notification.notifiable.user.login}' created a report for a request. This is the reason:"
    when 'Event::ReportForComment'
      "'#{@notification.notifiable.user.login}' created a report for a comment from #{@notification.event_payload['commenter']}. This is the reason:"
    when 'Event::ClearedDecision'
      "'#{@notification.notifiable.moderator.login}' decided to clear the report. This is the reason:"
    when 'Event::FavoredDecision'
      "'#{@notification.notifiable.moderator.login}' decided to favor the report. This is the reason:"
    when 'Event::AppealCreated'
      "'#{@notification.notifiable.appellant.login}' appealled the decision for the following reason:"
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
