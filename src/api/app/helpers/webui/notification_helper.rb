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
      source_and_target(notification)
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

  def notifiable_link(notification)
    return link_to(notifiable_link_text(notification), notifiable_link_path(notification), class: 'mx-1') if notifiable_link_path(notification).present?

    tag.span(notifiable_link_text(notification), class: 'fst-italic mx-1')
  end

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

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def notifiable_link_text(notification)
    case notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      "#{request_type_of_action(notification.notifiable)} Request ##{notification.notifiable.number}"
    when 'Event::CommentForRequest'
      "Comment on #{request_type_of_action(bs_request(notification))} Request ##{bs_request(notification).number}"
    when 'Event::CommentForProject'
      'Comment on Project'
    when 'Event::CommentForPackage'
      'Comment on Package'
    when 'Event::RelationshipCreate'
      role = notification.event_payload['role']
      if notification.event_payload['package']
        "Added as #{role} of a package"
      else
        "Added as #{role} of a project"
      end
    when 'Event::RelationshipDelete'
      role = notification.event_payload['role']
      if notification.event_payload['package']
        "Removed as #{role} of a package"
      else
        "Removed as #{role} of a project"
      end
    when 'Event::AddedUserToGroup'
      "#{notification.event_payload['who'] || Someone} added you to the group '#{notification.event_payload['group']}'"
    when 'Event::RemovedUserFromGroup'
      "#{notification.event_payload['who'] || Someone} removed you from the group '#{notification.event_payload['group']}'"
    when 'Event::BuildFail'
      project = notification.event_payload['project']
      package = notification.event_payload['package']
      repository = notification.event_payload['repository']
      arch = notification.event_payload['arch']
      "Package #{package} on #{project} project failed to build against #{repository} / #{arch}"
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport', 'Event::ReportForUser'
      "Report for a #{notification.event_payload['reportable_type']}"
    when 'Event::ReportForComment'
      if Comment.exists?(notification.event_payload['reportable_id'])
        'Report for a comment'
      else
        'Report for a deleted comment'
      end
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      notification.event_type.constantize.notification_link_text(notification.event_payload)
    when 'Event::ReportForRequest'
      "Report for Request ##{notification.notifiable.reportable.number}"
    when 'Event::ClearedDecision'
      # All reports should point to the same reportable. We will take care of that here:
      # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
      # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
      "Cleared #{notification.notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::FavoredDecision'
      # All reports should point to the same reportable. We will take care of that here:
      # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
      # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
      "Favored #{notification.notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::AppealCreated'
      "Appealed the decision for a report of #{notification.notifiable.decision.moderator.login}"
    when 'Event::WorkflowRunFail'
      'Workflow Run'
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def notifiable_link_path(notification)
    case notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      request_show_path(notification.notifiable.number, notification_id: notification.id)
    when 'Event::CommentForRequest'
      anchor = if Flipper.enabled?(:request_show_redesign, User.session!)
                 "comment-#{notification.notifiable.id}-bubble"
               else
                 'comments-list'
               end
      request_show_path(bs_request(notification).number, notification_id: notification.id, anchor: anchor)
    when 'Event::CommentForProject'
      project_show_path(notification.notifiable.commentable, notification_id: notification.id, anchor: 'comments-list')
    when 'Event::CommentForPackage'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #       but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      package = notification.notifiable.commentable
      package_show_path(package: package,
                        project: package.project,
                        notification_id: notification.id,
                        anchor: 'comments-list')
    when 'Event::RelationshipCreate', 'Event::RelationshipDelete'
      if notification.event_payload['package']
        package_users_path(notification.event_payload['project'],
                           notification.event_payload['package'],
                           notification_id: notification.id)
      else
        project_users_path(notification.event_payload['project'], notification_id: notification.id)
      end
    when 'Event::AddedUserToGroup', 'Event::RemovedUserFromGroup'
      group_path(notification.event_payload['group']) if Group.exists?(title: notification.event_payload['group'])
    when 'Event::BuildFail'
      package_live_build_log_path(package: notification.event_payload['package'], project: notification.event_payload['project'],
                                  repository: notification.event_payload['repository'], arch: notification.event_payload['arch'],
                                  notification_id: notification.id)
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport'
      reportable = notification.notifiable.reportable
      link_for_reportables(reportable)
    when 'Event::ReportForComment'
      # Do not have a link for deleted comments
      Comment.exists?(notification.event_payload['reportable_id']) && path_to_commentables_on_reports(event_payload: notification.event_payload, notification_id: notification.id)
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      notification.event_type.constantize.notification_link_path(notification)
    when 'Event::ReportForUser'
      user_path(notification.accused, notification_id: notification.id) if !notification.accused.is_deleted? || User.session!.is_admin?
    when 'Event::ReportForRequest'
      bs_request = notification.notifiable.reportable
      request_show_path(bs_request.number, notification_id: notification.id)
    when 'Event::ClearedDecision', 'Event::FavoredDecision'
      reportable = notification.notifiable.reports.first.reportable
      link_for_reportables(reportable)
    when 'Event::AppealCreated'
      appeal_path(notification.notifiable, notification_id: notification.id)
    when 'Event::WorkflowRunFail'
      token_workflow_run_path(notification.notifiable.token, notification.notifiable, notification_id: notification.id)
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes.
  # This method is also used by 'Event::ClearedDecision' and 'Event::FavoredDecision', this need to
  # be adapted
  def link_for_reportables(reportable)
    return '#' unless reportable

    case notification.event_payload['reportable_type']
    when 'Comment'
      link_for_commentables_on_reportables(commentable: reportable.commentable)
    when 'Package'
      package_show_path(package: reportable,
                        project: reportable.project,
                        notification_id: notification.id,
                        anchor: 'comments-list')
    when 'Project'
      project_show_path(reportable, notification_id: notification.id, anchor: 'comments-list')
    when 'User'
      user_path(reportable)
    end
  end

  def link_for_commentables_on_reportables(commentable:)
    case commentable
    when BsRequest
      request_show_path(commentable.number, notification_id: notification.id, anchor: 'comments-list')
    when BsRequestAction
      request_show_path(number: commentable.bs_request.number, request_action_id: commentable.id,
                        notification_id: notification.id, anchor: 'tab-pane-changes')
    when Package
      package_show_path(package: commentable,
                        project: commentable.project,
                        notification_id: notification.id,
                        anchor: 'comments-list')
    when Project
      project_show_path(commentable, notification_id: notification.id, anchor: 'comments-list')
    end
  end

  def path_to_commentables_on_reports(event_payload:, notification_id:)
    case event_payload['commentable_type']
    when 'BsRequest'
      request_show_path(event_payload['bs_request_number'],
                        notification_id: notification_id, anchor: 'comments-list')
    when 'BsRequestAction'
      request_show_path(number: event_payload['bs_request_number'],
                        request_action_id: event_payload['bs_request_action_id'],
                        notification_id: notification_id, anchor: 'tab-pane-changes')
    when 'Package'
      package_show_path(package: event_payload['package_name'],
                        project: event_payload['project_name'],
                        notification_id: notification_id,
                        anchor: 'comments-list')
    when 'Project'
      project_show_path(event_payload['project_name'], notification_id: notification_id,
                                                       anchor: 'comments-list')
    end
  end
end
