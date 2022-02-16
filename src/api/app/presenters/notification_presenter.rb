class NotificationPresenter < SimpleDelegator
  def initialize(model)
    @model = model
    super(@model)
  end

  def notifiable_link
    case @model.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      { text: "#{type_of_action(@model.notifiable)} Request ##{@model.notifiable.number}",
        path: Rails.application.routes.url_helpers.request_show_path(@model.notifiable.number, notification_id: @model.id) }
    when 'Event::CommentForRequest'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #      but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      bs_request = @model.notifiable.commentable
      { text: "Comment on #{type_of_action(bs_request)} Request",
        path: Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: @model.id, anchor: 'comments-list') }
    when 'Event::CommentForProject'
      { text: 'Comment on Project',
        path: Rails.application.routes.url_helpers.project_show_path(@model.notifiable.commentable, notification_id: @model.id, anchor: 'comments-list') }
    when 'Event::CommentForPackage'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #       but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      package = @model.notifiable.commentable
      { text: 'Comment on Package',
        path: Rails.application.routes.url_helpers.package_show_path(package: package,
                                                                     project: package.project,
                                                                     notification_id: @model.id,
                                                                     anchor: 'comments-list') }
    else
      {}
    end
  end

  def commenters
    commentable = @model.notifiable.commentable
    commentable.comments.where('updated_at >= ?', @model.unread_date).map(&:user).uniq
  end

  def avatar_objects
    if @model.notifiable_type == 'Comment'
      commenters
    else
      @model.notifiable.reviews.in_state_new.map(&:reviewed_by) + User.where(login: @model.notifiable.creator)
    end
  end

  private

  # Returns strings like "Add Role", "Submit", etc.
  def type_of_action(bs_request)
    return 'Multiple Actions\'' if bs_request.bs_request_actions.size > 1

    bs_request.bs_request_actions.first.type.titleize
  end
end
