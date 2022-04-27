class NotificationNotifiableLinkComponent < ApplicationComponent
  def initialize(notification)
    super

    @notification = notification
  end

  def call
    link_to(notifiable_link_text, notifiable_link_path, class: 'mx-1')
  end

  private

  def notifiable_link_text
    case @notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      "#{helpers.request_type_of_action(@notification.notifiable)} Request ##{@notification.notifiable.number}"
    when 'Event::CommentForRequest'
      bs_request = @notification.notifiable.commentable
      "Comment on #{helpers.request_type_of_action(bs_request)} Request ##{bs_request.number}"
    when 'Event::CommentForProject'
      'Comment on Project'
    when 'Event::CommentForPackage'
      'Comment on Package'
    end
  end

  def notifiable_link_path
    case @notification.event_type
    when 'Event::RequestStatechange', 'Event::RequestCreate', 'Event::ReviewWanted'
      Rails.application.routes.url_helpers.request_show_path(@notification.notifiable.number, notification_id: @notification.id)
    when 'Event::CommentForRequest'
      # TODO: It would be better to eager load the commentable association with `includes(...)`,
      #      but it's complicated since this isn't for all notifications and it's nested 2 levels deep.
      bs_request = @notification.notifiable.commentable
      Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: @notification.id, anchor: 'comments-list')
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
    end
  end
end
