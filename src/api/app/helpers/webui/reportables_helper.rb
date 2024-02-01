# TODO: Remove this helper after all `Event::CreateReport` records are migrated to the STI report classes
module Webui::ReportablesHelper
  include Webui::WebuiHelper

  def link_to_reportables(report_id:, reportable_type:, host:)
    reportable = Report.find(report_id).reportable
    return "The reported #{reportable_type.downcase} does not exist anymore." if reportable.blank?

    case reportable_type
    when 'Comment'
      link_to_commentables_on_reportables(commentable: reportable.commentable, host: host)
    when 'Package'
      link_to("#{reportable.name}", Rails.application.routes.url_helpers.package_show_url(package: reportable, project: reportable.project,
                                                                                          anchor: 'comments-list', only_path: false, host: host))
    when 'Project'
      link_to("#{reportable.name}", Rails.application.routes.url_helpers.project_show_url(reportable, anchor: 'comments-list', only_path: false, host: host))
    when 'User'
      link_to("#{reportable.login}", Rails.application.routes.url_helpers.user_url(reportable, only_path: false, host: host))
    end
  end

  def link_to_commentables_on_reportables(commentable:, host:)
    case commentable
    when BsRequest
      link_to("Request #{commentable.number}", Rails.application.routes.url_helpers.request_show_url(commentable.number, anchor: 'comments-list', only_path: false, host: host))
    when BsRequestAction
      link_to("Request #{commentable.bs_request.number}", Rails.application.routes.url_helpers.request_show_url(number: commentable.bs_request.number,
                                                                                                                request_action_id: commentable.id,
                                                                                                                anchor: 'tab-pane-changes', only_path: false, host: host))
    when Package
      link_to("#{commentable.name}", Rails.application.routes.url_helpers.package_show_url(package: commentable, project: commentable.project,
                                                                                           anchor: 'comments-list', only_path: false, host: host))
    when Project
      link_to("#{commentable.name}", Rails.application.routes.url_helpers.project_show_url(commentable, anchor: 'comments-list', only_path: false, host: host))
    end
  end

  def commentable_path(comment:)
    anchor = "comment-#{comment.id}"
    case comment.commentable
    when BsRequest
      Rails.application.routes.url_helpers.request_show_path(comment.commentable.number,
                                                             anchor: anchor)
    when BsRequestAction
      Rails.application.routes.url_helpers.request_show_path(number: comment.commentable.bs_request.number,
                                                             request_action_id: comment.commentable.id,
                                                             anchor: 'tab-pane-changes')
    when Package
      Rails.application.routes.url_helpers.package_show_path(package: comment.commentable,
                                                             project: comment.commentable.project,
                                                             anchor: anchor)
    when Project
      Rails.application.routes.url_helpers.project_show_path(comment.commentable,
                                                             anchor: anchor)
    end
  end
end
