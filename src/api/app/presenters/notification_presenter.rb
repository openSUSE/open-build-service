class NotificationPresenter < SimpleDelegator
  def initialize(model)
    @model = model
    super(@model)
  end

  def notifiable_link
    case @model.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      { text: "Request ##{@model.notifiable.number}",
        path: Rails.application.routes.url_helpers.request_show_path(@model.notifiable.number) }
    when 'Event::CommentForRequest'
      { text: "Request ##{@model.notifiable.commentable.number}",
        path: Rails.application.routes.url_helpers.request_show_path(@model.notifiable.commentable.number, anchor: 'comments-list') }
    when 'Event::CommentForProject'
      { text: @model.notifiable.commentable.name,
        path: Rails.application.routes.url_helpers.project_show_path(@model.notifiable.commentable, anchor: 'comments-list') }
    when 'Event::CommentForPackage'
      commentable = @model.notifiable.commentable
      { text: "#{commentable.project.name} / #{commentable.name}",
        path: Rails.application.routes.url_helpers.package_show_path(package: @model.notifiable.commentable,
                                                                     project: @model.notifiable.commentable.project,
                                                                     anchor: 'comments-list') }
    else
      {}
    end
  end

  def excerpt
    text =  case @model.notifiable_type
            when 'BsRequest'
              @model.notifiable.description
            when 'Review'
              @model.notifiable.reason
            when 'Comment'
              @model.notifiable.body
            else
              ''
            end
    text.to_s.truncate(100)
  end

  def kind_of_request
    return unless @model.notifiable_type == 'BsRequest'

    request = @model.notifiable
    return "Multiple actions for project #{request.bs_request_actions.first.target_project}" if request.bs_request_actions.size > 1

    BsRequest.actions_summary(@model.event_payload)
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
end
