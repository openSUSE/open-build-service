module Webui::ReportablesHelper
  include Webui::WebuiHelper

  LINK_TEXT = {
    'Package': 'package_name',
    'Project': 'project_name',
    'BsRequest': 'request_number',
    'BsRequestAction': 'request_number',
    'User': 'user_login'
  }

  # def link_to_reportables(payload:, host:)
  #   reportable = Report.find(payload['id']).reportable
  #   case payload['reportable_type']
  #   when 'Comment'
  #     link_to_commentables_on_reportables(commentable: reportable.commentable, host: host)
  #   when 'Package'
  #     link_to("#{reportable.name}", Rails.application.routes.url_helpers.package_show_path(package: reportable, project: reportable.project,
  #                                                                                          anchor: 'comments-list', only_path: false, host: host))
  #   when 'Project'
  #     link_to("#{reportable.name}", Rails.application.routes.url_helpers.project_show_path(reportable, anchor: 'comments-list', only_path: false, host: host))
  #   when 'User'
  #     link_to("#{reportable.login}", Rails.application.routes.url_helpers.user_path(reportable, only_path: false, host: host))
  #   end
  # end

  # def link_to_commentables_on_reportables(commentable:, host:)
  #   case commentable
  #   when BsRequest
  #     link_to("Request #{commentable.number}", Rails.application.routes.url_helpers.request_show_path(commentable.number, anchor: 'comments-list', only_path: false, host: host))
  #   when BsRequestAction
  #     link_to("Request #{commentable.bs_request.number}", Rails.application.routes.url_helpers.request_show_path(number: commentable.bs_request.number,
  #                                                                                                                request_action_id: commentable.id,
  #                                                                                                                anchor: 'tab-pane-changes', only_path: false, host: host))
  #   when Package
  #     link_to("#{commentable.name}", Rails.application.routes.url_helpers.package_show_path(package: commentable, project: commentable.project,
  #                                                                                           anchor: 'comments-list', only_path: false, host: host))
  #   when Project
  #     link_to("#{commentable.name}", Rails.application.routes.url_helpers.project_show_path(commentable, anchor: 'comments-list', only_path: false, host: host))
  #   end
  # end

  def link_to_reportables(event_payload:, **kwargs)
    link_text =
  end

  def path_to_reportables(event_payload:, **kwargs)
    case event_payload['reportable_type']
    when 'Package'
      Rails.application.routes.url_helpers.package_show_path(package: event_payload['package_name'] ,
                                                             project: event_payload['project_name'],
                                                             notification_id: kwargs[:notification_id],
                                                             anchor: 'comments-list',
                                                             only_path: kwargs[:only_path],
                                                             host: kwargs[:host])
    when 'Project'
      Rails.application.routes.url_helpers.project_show_path(event_payload['project_name'], notification_id: kwargs[:notification_id], anchor: 'comments-list',
                                                             only_path: kwargs[:only_path], host: kwargs[:host])
    when 'User'
      Rails.application.routes.url_helpers.user_path(event_payload['user_login'], only_path: kwargs[:only_path], host: kwargs[:host])
    when 'Comment'
      link_to_commentables_on_reports(event_payload: event_payload, notification_id: kwargs[:notification_id],
                                      only_path: kwargs[:only_path], host: kwargs[:host])
    end
  end

  def path_to_commentables_on_reports(event_payload:, **kwargs)
    case event_payload['commentable_type']
    when 'BsRequest'
      Rails.application.routes.url_helpers.request_show_path(event_payload['bs_request_number'],
                                                             notification_id: kwargs[:notification_id], anchor: 'comments-list',
                                                             only_path: kwargs[:only_path], host: kwargs[:host])
    when 'BsRequestAction'
      Rails.application.routes.url_helpers.request_show_path(number: event_payload['bs_request_number'],
                                                             request_action_id: event_payload['bs_request_action_id'],
                                                             notification_id: kwargs[:notification_id], anchor: 'tab-pane-changes',
                                                             only_path: kwargs[:only_path], host: kwargs[:host])
    when 'Package'
      Rails.application.routes.url_helpers.package_show_path(package: event_payload['package_name'],
                                                             project: event_payload['project_name'],
                                                             notification_id: kwargs[:notification_id],
                                                             anchor: 'comments-list', only_path: kwargs[:only_path],
                                                             host: kwargs[:host])
    when 'Project'
      Rails.application.routes.url_helpers.project_show_path(event_payload['project_name'], notification_id: kwargs[:notification_id],
                                                             anchor: 'comments-list', only_path: kwargs[:only_path], host: kwargs[:host])
    end
  end
end
