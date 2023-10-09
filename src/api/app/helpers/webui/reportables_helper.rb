module Webui::ReportablesHelper
  include Webui::WebuiHelper

  def link_to_reportables(reportable:, host: nil)
    case reportable
    when Comment
      link_to_commentables_on_reportables(commentable: reportable.commentable, host:)
    when Package, Project
      link_to("#{reportable.name}", link_for_reportables(reportable:, host:))
    when User
      link_to("#{reportable.login}", link_for_reportables(reportable:, host:))
    end
  end

  def link_to_commentables_on_reportables(commentable:, host: nil)
    case commentable
    when BsRequest
      link_to("Request #{commentable.number}", link_for_commentables_on_reportables(commentable:, host:))
    when BsRequestAction
      link_to("Request #{commentable.bs_request.number}", link_for_commentables_on_reportables(commentable:, host:))
    when Package, Project
      link_to("#{commentable.name}", link_for_commentables_on_reportables(commentable:, host:))
    end
  end

  def link_for_reportables(reportable:, host: nil, notification: nil)
    case reportable
    when Comment
      link_for_commentables_on_reportables(commentable: reportable.commentable, host:, notification:)
    when Package
      Rails.application.routes.url_helpers.package_show_path({ package: reportable,
                                                               project: reportable.project,
                                                               notification_id: notification&.id,
                                                               anchor: 'comments-list' }.merge(opts_for_reportables(host)))
    when Project
      Rails.application.routes.url_helpers.project_show_path(reportable, { notification_id: notification&.id, anchor: 'comments-list' }.merge(opts_for_reportables(host)))
    when User
      Rails.application.routes.url_helpers.user_path(reportable, opts_for_reportables(host))
    end
  end

  def link_for_commentables_on_reportables(commentable:, host: nil, notification: nil)
    case commentable
    when BsRequest
      Rails.application.routes.url_helpers.request_show_path(commentable.number, { notification_id: notification&.id, anchor: 'comments-list' }.merge(opts_for_reportables(host)))
    when BsRequestAction
      Rails.application.routes.url_helpers.request_show_path({ number: commentable.bs_request.number, request_action_id: commentable.id,
                                                               notification_id: notification&.id, anchor: 'tab-pane-changes' }.merge(opts_for_reportables(host)))
    when Package
      Rails.application.routes.url_helpers.package_show_path({ package: commentable,
                                                               project: commentable.project,
                                                               notification_id: notification&.id,
                                                               anchor: 'comments-list' }.merge(opts_for_reportables(host)))
    when Project
      Rails.application.routes.url_helpers.project_show_path(commentable, { notification_id: notification&.id, anchor: 'comments-list' }.merge(opts_for_reportables(host)))
    end
  end

  private

  def opts_for_reportables(host)
    return {} unless host

    { only_path: false, host: }
  end
end
