class Decorators::Notification::Event::ReportForComment < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a comment from #{notification.event_payload['commenter']}. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    if Comment.exists?(notification.event_payload['reportable_id'])
      'Report for a comment'
    else
      'Report for a deleted comment'
    end
  end

  def notifiable_link_path
    # Do not have a link for deleted comments
    Comment.exists?(notification.event_payload['reportable_id']) &&
      path_to_commentables_on_reports(event_payload: notification.event_payload,
                                      notification_id: notification.id)
  end

  private

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
