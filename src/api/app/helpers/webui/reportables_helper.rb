# TODO: Remove this helper after all `Event::CreateReport` records are migrated to the STI report classes
module Webui::ReportablesHelper
  include Webui::WebuiHelper

  def link_to_reportables(payload:, host:)
    reportable = Report.find(payload['id']).reportable
    case payload['reportable_type']
    when 'Comment'
      link_to_commentables_on_reportables(commentable: reportable.commentable, host: host)
    when 'Package'
      link_to("#{reportable.name}", Rails.application.routes.url_helpers.package_show_path(package: reportable, project: reportable.project,
                                                                                           anchor: 'comments-list', only_path: false, host: host))
    when 'Project'
      link_to("#{reportable.name}", Rails.application.routes.url_helpers.project_show_path(reportable, anchor: 'comments-list', only_path: false, host: host))
    when 'User'
      link_to("#{reportable.login}", Rails.application.routes.url_helpers.user_path(reportable, only_path: false, host: host))
    end
  end

  def link_to_commentables_on_reportables(commentable:, host:)
    case commentable
    when BsRequest
      link_to("Request #{commentable.number}", Rails.application.routes.url_helpers.request_show_path(commentable.number, anchor: 'comments-list', only_path: false, host: host))
    when BsRequestAction
      link_to("Request #{commentable.bs_request.number}", Rails.application.routes.url_helpers.request_show_path(number: commentable.bs_request.number,
                                                                                                                 request_action_id: commentable.id,
                                                                                                                 anchor: 'tab-pane-changes', only_path: false, host: host))
    when Package
      link_to("#{commentable.name}", Rails.application.routes.url_helpers.package_show_path(package: commentable, project: commentable.project,
                                                                                            anchor: 'comments-list', only_path: false, host: host))
    when Project
      link_to("#{commentable.name}", Rails.application.routes.url_helpers.project_show_path(commentable, anchor: 'comments-list', only_path: false, host: host))
    end
  end
end
