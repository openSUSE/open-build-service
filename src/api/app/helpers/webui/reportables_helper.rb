module Webui::ReportablesHelper
  include Webui::WebuiHelper

  def reportable_not_found(reportable_type:)
    "The reported #{reportable_type.blank? ? 'object' : reportable_type.downcase} does not exist anymore."
  end

  def link_to_reportables(report_id:, reportable_type:, host: nil)
    reportable = Report.find(report_id).reportable
    return reportable_not_found(reportable_type: reportable_type) if reportable.blank?

    only_path = host.blank?

    case reportable_type
    when 'Comment'
      link_to_commentables_on_reportables(commentable: reportable.commentable, only_path: only_path, host: host)
    when 'Package'
      link_to(reportable.name.to_s, Rails.application.routes.url_helpers.package_show_url(package: reportable, project: reportable.project,
                                                                                          anchor: 'comments-list', only_path: only_path, host: host))
    when 'Project'
      link_to(reportable.name.to_s, Rails.application.routes.url_helpers.project_show_url(reportable, anchor: 'comments-list', only_path: only_path, host: host))
    when 'User'
      link_to(reportable.login.to_s, Rails.application.routes.url_helpers.user_url(reportable, only_path: only_path, host: host))
    end
  end

  def link_to_commentables_on_reportables(commentable:, only_path:, host:)
    case commentable
    when BsRequest
      link_to("Request #{commentable.number}", Rails.application.routes.url_helpers.request_show_url(commentable.number, anchor: 'comments-list', only_path: only_path, host: host))
    when BsRequestAction
      link_to("Request #{commentable.bs_request.number}", Rails.application.routes.url_helpers.request_show_url(number: commentable.bs_request.number,
                                                                                                                request_action_id: commentable.id,
                                                                                                                anchor: 'tab-pane-changes', only_path: only_path, host: host))
    when Package
      link_to(commentable.name.to_s, Rails.application.routes.url_helpers.package_show_url(package: commentable, project: commentable.project,
                                                                                           anchor: 'comments-list', only_path: only_path, host: host))
    when Project
      link_to(commentable.name.to_s, Rails.application.routes.url_helpers.project_show_url(commentable, anchor: 'comments-list', only_path: only_path, host: host))
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
