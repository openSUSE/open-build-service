# rubocop:disable Metrics/ClassLength
class NotificationNotifiableLinkComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
  end

  def call
    return link_to(notifiable_link_text, notifiable_link_path, class: 'mx-1') if notifiable_link_path.present?

    tag.span(notifiable_link_text, class: 'fst-italic mx-1')
  end

  private

  def notifiable_link_text
    @notification.decorator.notifiable_link_text(helpers)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def notifiable_link_path
    case @notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      Rails.application.routes.url_helpers.request_show_path(@notification.notifiable.number, notification_id: @notification.id)
    when 'Event::CommentForRequest'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #      but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      anchor = if @notification.notifiable.commentable.is_a?(BsRequestAction)
                 'tab-pane-changes'
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
      Rails.application.routes.url_helpers.user_path(@notification.event_payload['user_login'])
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
