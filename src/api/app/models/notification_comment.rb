class NotificationComment < Notification
  # TODO: rename to title once we get rid of Notification#title
  def summary
    case notifiable.commentable_type
    when 'BsRequest'
      "Comment on #{request_type_of_action(bs_request)} Request ##{bs_request.number}"
    when 'Project'
      'Comment on Project'
    when 'Package'
      'Comment on Package'
    end
  end

  def description
    case notifiable.commentable_type
    when 'BsRequest'
      "From #{request_source} to #{request_target}"
    when 'Project'
      notifiable.commentable.name
    when 'Package'
      commentable = notifiable.commentable
      "#{commentable.project.name} / #{commentable.name}"
    end
  end

  def excerpt
    notifiable.body
  end

  def involved_users
    comments = notifiable.commentable.comments
    comments.select { |comment| comment.updated_at >= unread_date }.map(&:user).uniq
  end
end