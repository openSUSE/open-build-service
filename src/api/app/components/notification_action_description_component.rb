class NotificationActionDescriptionComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
    @role = @notification.event_payload['role']
    @user = @notification.event_payload['who']
    @target_object = if @notification.event_payload['package']
                       "#{@notification.event_payload['project']} / #{@notification.event_payload['package']}"
                     else
                       @notification.event_payload['project']
                     end
  end

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
        "#{@user} made you #{@role} of #{@target_object}"
      when 'Event::RelationshipDelete'
        "#{@user} removed you as #{@role} of #{@target_object}"
      end
    end
  end

  private

  def bs_request
    @bs_request ||= @notification.notifiable_type == 'BsRequest' ? @notification.notifiable : @notification.notifiable.commentable
  end
end
