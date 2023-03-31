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
end
