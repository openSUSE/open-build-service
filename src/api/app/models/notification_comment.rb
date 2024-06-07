class NotificationComment < Notification
  include NotificationRequest

  def description
    case notifiable.commentable_type
    when 'BsRequest'
      if request_source.blank?
        "To #{request_target}"
      else
        "From #{request_source} to #{request_target}"
      end
    when 'Project'
      notifiable.commentable.name
    when 'Package'
      "#{notifiable.commentable.project.name} / #{notifiable.commentable.name}"
    end
  end

  def excerpt
    notifiable.body
  end

  def avatar_objects
    comments = notifiable.commentable.comments
    comments.select { |comment| comment.updated_at >= unread_date }.map(&:user).uniq.compact
  end

  def link_text
    case event_type
    when 'Event::CommentForRequest'
      "Comment on #{request_type_of_action} Request ##{bs_request.number}"
    when 'Event::CommentForProject'
      'Comment on Project'
    when 'Event::CommentForPackage'
      'Comment on Package'
    end
  end

  def link_path
    case event_type
    when 'Event::CommentForRequest'
      anchor = if Flipper.enabled?(:request_show_redesign, User.session!)
                 "comment-#{notifiable.id}-bubble"
               else
                 'comments-list'
               end
      Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: id, anchor: anchor)
    when 'Event::CommentForProject'
      Rails.application.routes.url_helpers.project_show_path(notifiable.commentable, notification_id: id, anchor: 'comments-list')
    when 'Event::CommentForPackage'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #       but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      package = notifiable.commentable
      Rails.application.routes.url_helpers.package_show_path(package: package,
                                                             project: package.project,
                                                             notification_id: id,
                                                             anchor: 'comments-list')
    end
  end

  def bs_request
    if notifiable.commentable.is_a?(BsRequestAction)
      notifiable.commentable.bs_request
    elsif notifiable.commentable.is_a?(BsRequest)
      notifiable.commentable
    end
  end
end
