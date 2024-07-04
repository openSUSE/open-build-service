module Webui::NotificationHelper
  TRUNCATION_LENGTH = 100
  TRUNCATION_ELLIPSIS_LENGTH = 3 # `...` is the default ellipsis for String#truncate

  # TODO: Content of ViewComponent. Move to sub-classes once STI is set.
  def excerpt(notification)
    text = case notification.notifiable.class.name
           when 'BsRequest'
             notification.notifiable.description
           when 'Comment'
             notification.notifiable.body
           when 'Report', 'Decision', 'Appeal', 'DecisionFavoredWithDeleteRequest', 'DecisionFavoredWithUserCommentingRestrictions', 'DecisionFavoredWithCommentModeration', 'DecisionFavoredWithUserDeletion'
             notification.notifiable.reason
           when 'WorkflowRun'
             "In repository #{notification.notifiable.repository_full_name}"
           else
             ''
           end

    truncate_to_first_new_line(text.to_s) # sometimes text can be nil
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # TODO: Content of ViewComponent. Move to sub-classes once STI is set.
  def description(notification)
    case notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted', 'Event::CommentForRequest'
      # TODO: find an alternative when this is moved to the STI model
      # FIXME: This will try to fetch a dedicated Notification subclass, or use the legacy method otherwise
      notification.for_event_type&.description || source_and_target(notification)
    when 'Event::CommentForProject'
      "#{notification.notifiable.commentable.name}"
    when 'Event::CommentForPackage'
      commentable = notification.notifiable.commentable
      "#{commentable.project.name} / #{commentable.name}"
    when 'Event::RelationshipCreate'
      "#{notification.event_payload['who']} made #{recipient(notification)} #{notification.event_payload['role']} of #{target_object(notification)}"
    when 'Event::RelationshipDelete'
      "#{notification.event_payload['who']} removed #{recipient(notification)} as #{notification.event_payload['role']} of #{target_object(notification)}"
    when 'Event::BuildFail'
      "Build was triggered because of #{notification.event_payload['reason']}"
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport', 'Event::ReportForProject', 'Event::ReportForPackage', 'Event::ReportForUser'
      "'#{notification.notifiable.user.login}' created a report for a #{notification.event_payload['reportable_type'].downcase}. This is the reason:"
    when 'Event::ReportForRequest'
      "'#{notification.notifiable.user.login}' created a report for a request. This is the reason:"
    when 'Event::ReportForComment'
      "'#{notification.notifiable.user.login}' created a report for a comment from #{notification.event_payload['commenter']}. This is the reason:"
    when 'Event::ClearedDecision'
      "'#{notification.notifiable.moderator.login}' decided to clear the report. This is the reason:"
    when 'Event::FavoredDecision'
      "'#{notification.notifiable.moderator.login}' decided to favor the report. This is the reason:"
    when 'Event::AppealCreated'
      "'#{notification.notifiable.appellant.login}' appealed the decision for the following reason:"
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def mark_as_read_or_unread_button(notification)
    state = notification.unread? ? 'unread' : 'read'
    update_path = my_notifications_path(notification_ids: [notification.id], state: state)
    title, icon = notification.unread? ? ['Mark as read', 'fa-check'] : ['Mark as unread', 'fa-undo']
    link_to(update_path, id: dom_id(notification, :update), method: :put,
                         class: 'btn btn-sm btn-outline-success', title: title) do
      concat(tag.i(class: "#{icon} fas"))
      concat(" #{title}")
    end
  end

  def truncate_to_first_new_line(text)
    first_new_line_index = text.index("\n")
    truncation_index = !first_new_line_index.nil? && first_new_line_index < TRUNCATION_LENGTH ? first_new_line_index + TRUNCATION_ELLIPSIS_LENGTH : TRUNCATION_LENGTH
    text.truncate(truncation_index)
  end

  def bs_request(notification)
    if notification.notifiable_type == 'BsRequest'
      notification.notifiable
    elsif notification.notifiable.commentable.is_a?(BsRequestAction)
      notification.notifiable.commentable.bs_request
    else
      notification.notifiable.commentable
    end
  end

  def recipient(notification)
    # If a notification is for a group, the notified user needs to know for which group. Otherwise, the user is simply referred to as 'you'.
    notification.event_payload.fetch('group', 'you')
  end

  def target_object(notification)
    [notification.event_payload['project'], notification.event_payload['package']].compact.join(' / ')
  end

  def source(notification)
    first_bs_request_action = bs_request(notification).bs_request_actions.first

    return '' if bs_request(notification).bs_request_actions.size > 1

    [first_bs_request_action.source_project, first_bs_request_action.source_package].compact.join(' / ')
  end

  def target(notification)
    first_bs_request_action = bs_request(notification).bs_request_actions.first

    return first_bs_request_action.target_project if bs_request(notification).bs_request_actions.size > 1

    [first_bs_request_action.target_project, first_bs_request_action.target_package].compact.join(' / ')
  end

  def source_and_target(notification)
    capture do
      if source(notification).present?
        concat(tag.span(source(notification)))
        concat(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))
      end
      concat(tag.span(target(notification)))
    end
  end
end
