# rubocop:disable Metrics/ClassLength
class NotificationNotifiableLinkComponent < ApplicationComponent
  def initialize(notification, current_user)
    super

    @notification = notification
    @current_user = current_user
  end

  def call
    return link_to(notifiable_link_text, notifiable_link_path, class: 'mx-1') if notifiable_link_path.present?

    tag.span(notifiable_link_text, class: 'fst-italic mx-1')
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def notifiable_link_text
    case @notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      "#{helpers.request_type_of_action(@notification.notifiable)} Request ##{@notification.notifiable.number}"
    when 'Event::CommentForRequest'
      "Comment on #{helpers.request_type_of_action(bs_request)} Request ##{bs_request.number}"
    when 'Event::CommentForProject'
      'Comment on Project'
    when 'Event::CommentForPackage'
      'Comment on Package'
    when 'Event::RelationshipCreate'
      role = @notification.event_payload['role']
      if @notification.event_payload['package']
        "Added as #{role} of a package"
      else
        "Added as #{role} of a project"
      end
    when 'Event::RelationshipDelete'
      role = @notification.event_payload['role']
      if @notification.event_payload['package']
        "Removed as #{role} of a package"
      else
        "Removed as #{role} of a project"
      end
    when 'Event::BuildFail'
      project = @notification.event_payload['project']
      package = @notification.event_payload['package']
      repository = @notification.event_payload['repository']
      arch = @notification.event_payload['arch']
      "Package #{package} on #{project} project failed to build against #{repository} / #{arch}"
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport', 'Event::ReportForUser'
      "Report for a #{@notification.event_payload['reportable_type']}"
    when 'Event::ReportForComment'
      if Comment.exists?(@notification.event_payload['reportable_id'])
        'Report for a comment'
      else
        'Report for a deleted comment'
      end
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      @notification.event_type.constantize.notification_link_text(@notification.event_payload)
    when 'Event::ReportForRequest'
      "Report for Request ##{@notification.notifiable.reportable.number}"
    when 'Event::ClearedDecision'
      # All reports should point to the same reportable. We will take care of that here:
      # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
      # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
      "Cleared #{@notification.notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::FavoredDecision'
      # All reports should point to the same reportable. We will take care of that here:
      # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
      # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
      "Favored #{@notification.notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::AppealCreated'
      "Appealed the decision for a report of #{@notification.notifiable.decision.moderator.login}"
    when 'Event::WorkflowRunFail'
      'Workflow Run'
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def notifiable_link_path
    case @notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      Rails.application.routes.url_helpers.request_show_path(@notification.notifiable.number, notification_id: @notification.id)
    when 'Event::CommentForRequest'
      anchor = if Flipper.enabled?(:request_show_redesign, @current_user)
                 "comment-#{@notification.notifiable.id}-bubble"
               else
                 'comments-list'
               end
      Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: @notification.id, anchor: anchor)
    when 'Event::CommentForProject'
      Rails.application.routes.url_helpers.project_show_path(@notification.notifiable.commentable, notification_id: @notification.id, anchor: 'comments-list')
    when 'Event::CommentForPackage'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #       but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      package = @notification.notifiable.commentable
      Rails.application.routes.url_helpers.package_show_path(package: package,
                                                             project: package.project,
                                                             notification_id: @notification.id,
                                                             anchor: 'comments-list')
    when 'Event::RelationshipCreate', 'Event::RelationshipDelete'
      if @notification.event_payload['package']
        Rails.application.routes.url_helpers.package_users_path(@notification.event_payload['project'],
                                                                @notification.event_payload['package'])
      else
        Rails.application.routes.url_helpers.project_users_path(@notification.event_payload['project'])
      end
    when 'Event::BuildFail'
      Rails.application.routes.url_helpers.package_live_build_log_path(package: @notification.event_payload['package'], project: @notification.event_payload['project'],
                                                                       repository: @notification.event_payload['repository'], arch: @notification.event_payload['arch'])
    # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
    when 'Event::CreateReport'
      reportable = @notification.notifiable.reportable
      link_for_reportables(reportable)
    when 'Event::ReportForComment'
      # Do not have a link for deleted comments
      Comment.exists?(@notification.event_payload['reportable_id']) && path_to_commentables_on_reports(event_payload: @notification.event_payload, notification_id: @notification.id)
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      @notification.event_type.constantize.notification_link_path(@notification)
    when 'Event::ReportForUser'
      Rails.application.routes.url_helpers.user_path(@notification.event_payload['user_login'], notification_id: @notification.id) if !@notification.event_user.is_deleted? || @current_user.is_admin?
    when 'Event::ReportForRequest'
      bs_request = @notification.notifiable.reportable
      Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: @notification.id)
    when 'Event::ClearedDecision', 'Event::FavoredDecision'
      reportable = @notification.notifiable.reports.first.reportable
      link_for_reportables(reportable)
    when 'Event::AppealCreated'
      Rails.application.routes.url_helpers.appeal_path(@notification.notifiable)
    when 'Event::WorkflowRunFail'
      Rails.application.routes.url_helpers.token_workflow_run_path(@notification.notifiable.token, @notification.notifiable)
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def bs_request
    return unless @notification.event_type == 'Event::CommentForRequest'

    if @notification.notifiable.commentable.is_a?(BsRequestAction)
      @notification.notifiable.commentable.bs_request
    else
      @notification.notifiable.commentable
    end
  end

  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes.
  # This method is also used by 'Event::ClearedDecision' and 'Event::FavoredDecision', this need to
  # be adapted
  def link_for_reportables(reportable)
    return '#' unless reportable

    case @notification.event_payload['reportable_type']
    when 'Comment'
      link_for_commentables_on_reportables(commentable: reportable.commentable)
    when 'Package'
      Rails.application.routes.url_helpers.package_show_path(package: reportable,
                                                             project: reportable.project,
                                                             notification_id: @notification.id,
                                                             anchor: 'comments-list')
    when 'Project'
      Rails.application.routes.url_helpers.project_show_path(reportable, notification_id: @notification.id, anchor: 'comments-list')
    when 'User'
      Rails.application.routes.url_helpers.user_path(reportable)
    end
  end

  def link_for_commentables_on_reportables(commentable:)
    case commentable
    when BsRequest
      Rails.application.routes.url_helpers.request_show_path(commentable.number, notification_id: @notification.id, anchor: 'comments-list')
    when BsRequestAction
      Rails.application.routes.url_helpers.request_show_path(number: commentable.bs_request.number, request_action_id: commentable.id,
                                                             notification_id: @notification.id, anchor: 'tab-pane-changes')
    when Package
      Rails.application.routes.url_helpers.package_show_path(package: commentable,
                                                             project: commentable.project,
                                                             notification_id: @notification.id,
                                                             anchor: 'comments-list')
    when Project
      Rails.application.routes.url_helpers.project_show_path(commentable, notification_id: @notification.id, anchor: 'comments-list')
    end
  end

  def path_to_commentables_on_reports(event_payload:, notification_id:)
    case event_payload['commentable_type']
    when 'BsRequest'
      Rails.application.routes.url_helpers.request_show_path(event_payload['bs_request_number'],
                                                             notification_id: notification_id, anchor: 'comments-list')
    when 'BsRequestAction'
      Rails.application.routes.url_helpers.request_show_path(number: event_payload['bs_request_number'],
                                                             request_action_id: event_payload['bs_request_action_id'],
                                                             notification_id: notification_id, anchor: 'tab-pane-changes')
    when 'Package'
      Rails.application.routes.url_helpers.package_show_path(package: event_payload['package_name'],
                                                             project: event_payload['project_name'],
                                                             notification_id: notification_id,
                                                             anchor: 'comments-list')
    when 'Project'
      Rails.application.routes.url_helpers.project_show_path(event_payload['project_name'], notification_id: notification_id,
                                                                                            anchor: 'comments-list')
    end
  end
end
# rubocop:enable Metrics/ClassLength
