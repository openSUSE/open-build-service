class NotificationPresenter < SimpleDelegator
  def initialize(model)
    @model = model
    super(@model)
  end

  def link_to_notification_target
    case @model.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate'
      Rails.application.routes.url_helpers.request_show_path(@model.notifiable.number)
    when 'Event::ReviewWanted'
      Rails.application.routes.url_helpers.request_show_path(@model.event_payload['number'])
    when 'Event::CommentForRequest'
      Rails.application.routes.url_helpers.request_show_path(@model.event_payload['number'], anchor: "comment-#{@model.notifiable_id}")
    when 'Event::CommentForProject'
      Rails.application.routes.url_helpers.project_show_path(@model.notifiable.commentable, anchor: "comment-#{@model.notifiable_id}")
    when 'Event::CommentForPackage'
      Rails.application.routes.url_helpers.package_show_path(package: @model.notifiable.commentable,
                                                             project: @model.notifiable.commentable.project,
                                                             anchor: "comment-#{@model.notifiable_id}")
    else
      ''
    end
  end

  def notification_badge
    case @model.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate'
      'Request'
    when 'Event::ReviewWanted'
      'Review'
    when 'Event::CommentForRequest', 'Event::CommentForProject', 'Event::CommentForPackage'
      'Comment'
    end
  end
end
