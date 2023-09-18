# rubocop:disable Metrics/ClassLength
class NotificationNotifiableLinkComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
  end

  def call
    link_to(notifiable_link_text, notifiable_link_path, class: 'mx-1')
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity
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
    when 'Event::CreateReport'
      "Report for a #{@notification.event_payload['reportable_type'].downcase} created"
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
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
    when 'Event::CreateReport'
      link_for_reportables
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def bs_request
    return unless @notification.event_type == 'Event::CommentForRequest'

    if @notification.notifiable.commentable.is_a?(BsRequestAction)
      @notification.notifiable.commentable.bs_request
    else
      @notification.notifiable.commentable
    end
  end

  def link_for_reportables
    reportable = @notification.notifiable.reportable
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
      Rails.application.routes.url_helpers.user_show_path(reportable, notification_id: @notification.id)
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
end
# rubocop:enable Metrics/ClassLength
