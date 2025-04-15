# Notifications related to reports: reports, decisions and appeals.
class NotificationReport < Notification
  def description
    case event_type
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      "'#{notifiable.reporter.login}' created a report for a #{event_payload['reportable_type'].downcase}. This is the reason:"
    when 'Event::ReportForRequest'
      "'#{notifiable.reporter.login}' created a report for a request. This is the reason:"
    when 'Event::FavoredDecision'
      "'#{notifiable.moderator.login}' decided to favor the report. This is the reason:"
    when 'Event::ClearedDecision'
      "'#{notifiable.moderator.login}' decided to clear the report. This is the reason:"
    when 'Event::AppealCreated'
      "'#{notifiable.appellant.login}' appealed the decision for the following reason:"
    end
  end

  def excerpt
    notifiable.reason
  end

  def avatar_objects
    case event_type
    when 'Event::ReportForComment', 'Event::ReportForPackage', 'Event::ReportForProject', 'Event::ReportForUser', 'Event::ReportForRequest'
      [User.find_by(login: event_payload['reporter'])].compact
    when 'Event::FavoredDecision', 'Event::ClearedDecision'
      [User.find(event_payload['moderator_id'])].compact
    when 'Event::AppealCreated'
      [User.find(event_payload['appellant_id'])].compact
    end
  end

  def link_text
    case event_type
    when 'Event::ReportForComment'
      if Comment.exists?(event_payload['reportable_id'])
        'Report for a comment'
      else
        'Report for a deleted comment'
      end
    when 'Event::ReportForPackage', 'Event::ReportForProject'
      event_type.constantize.notification_link_text(event_payload)
    when 'Event::ReportForRequest'
      "Report for Request ##{notifiable.reportable.number}"
    when 'Event::ReportForUser'
      "Report for a #{event_payload['reportable_type']}"
    when 'Event::FavoredDecision'
      "Favored #{notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::ClearedDecision'
      "Cleared #{notifiable.reports.first.reportable&.class&.name} Report".squish
    when 'Event::AppealCreated'
      "Appealed the decision for a report of #{notifiable.decision.moderator.login}"
    end
  end

  # TODO: rename to title once we get rid of Notification#title
  # All reports should point to the same reportable. We will take care of that here:
  # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
  # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
  def link_path
    case event_type
    when 'Event::ReportForComment'
      # Do not have a link for deleted comments
      Comment.exists?(event_payload['reportable_id']) && path_to_commentables_on_reports(event_payload: event_payload, notification_id: id)
    when 'Event::ReportForProject', 'Event::ReportForPackage'
      event_type.constantize.notification_link_path(self)
    when 'Event::ReportForUser'
      Rails.application.routes.url_helpers.user_path(accused, notification_id: id) if !accused.deleted? || User.session!.admin?
    when 'Event::ReportForRequest'
      bs_request = notifiable.reportable
      Rails.application.routes.url_helpers.request_show_path(bs_request.number, notification_id: id)
    when 'Event::ClearedDecision', 'Event::FavoredDecision'
      reportable = notifiable.reports.first.reportable
      link_for_reportables(reportable)
    when 'Event::AppealCreated'
      Rails.application.routes.url_helpers.appeal_path(notifiable, notification_id: id)
    end
  end

  #
  # This method is also used by 'Event::ClearedDecision' and 'Event::FavoredDecision', this need to
  # be adapted
  def link_for_reportables(reportable)
    return '#' unless reportable

    case event_payload['reportable_type']
    when 'Comment'
      link_for_commentables_on_reportables(commentable: reportable.commentable)
    when 'Package'
      Rails.application.routes.url_helpers.package_show_path(package: reportable,
                                                             project: reportable.project,
                                                             notification_id: id,
                                                             anchor: 'comments-list')
    when 'Project'
      Rails.application.routes.url_helpers.project_show_path(reportable, notification_id: id, anchor: 'comments-list')
    when 'User'
      Rails.application.routes.url_helpers.user_path(reportable)
    end
  end

  def link_for_commentables_on_reportables(commentable:)
    case commentable
    when BsRequest
      Rails.application.routes.url_helpers.request_show_path(commentable.number, notification_id: id, anchor: 'comments-list')
    when BsRequestAction
      Rails.application.routes.url_helpers.request_show_path(number: commentable.bs_request.number, request_action_id: commentable.id,
                                                             notification_id: id, anchor: 'tab-pane-changes')
    when Package
      Rails.application.routes.url_helpers.package_show_path(package: commentable,
                                                             project: commentable.project,
                                                             notification_id: id,
                                                             anchor: 'comments-list')
    when Project
      Rails.application.routes.url_helpers.project_show_path(commentable, notification_id: id, anchor: 'comments-list')
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

# == Schema Information
#
# Table name: notifications
#
#  id                         :bigint           not null, primary key
#  bs_request_oldstate        :string(255)
#  bs_request_state           :string(255)
#  delivered                  :boolean          default(FALSE), indexed
#  event_payload              :text(16777215)   not null
#  event_type                 :string(255)      not null, indexed
#  last_seen_at               :datetime
#  notifiable_type            :string(255)      indexed => [notifiable_id]
#  rss                        :boolean          default(FALSE), indexed
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscription_receiver_role :string(255)      not null
#  title                      :string(255)
#  type                       :string(255)      indexed
#  web                        :boolean          default(FALSE), indexed
#  created_at                 :datetime         not null, indexed
#  updated_at                 :datetime         not null
#  notifiable_id              :integer          indexed => [notifiable_type]
#  subscriber_id              :integer          indexed => [subscriber_type]
#
# Indexes
#
#  index_notifications_on_created_at                         (created_at)
#  index_notifications_on_delivered                          (delivered)
#  index_notifications_on_event_type                         (event_type)
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_rss                                (rss)
#  index_notifications_on_subscriber_type_and_subscriber_id  (subscriber_type,subscriber_id)
#  index_notifications_on_type                               (type)
#  index_notifications_on_web                                (web)
#
