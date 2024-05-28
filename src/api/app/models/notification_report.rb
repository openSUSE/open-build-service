# Notifications related to reports: reports, decisions and appeals.
class NotificationReport < Notification
  # TODO: rename to title once we get rid of Notification#title
  # All reports should point to the same reportable. We will take care of that here:
  # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
  # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def summary
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
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def description
    case event_type
    when 'Event::ReportForComment'
      "'#{notifiable.user.login}' created a report for a comment from #{event_payload['commenter']}. This is the reason:"
    when 'Event::ReportForPackage', 'Event::ReportForProject', 'Event::ReportForUser'
      "'#{notifiable.user.login}' created a report for a #{event_payload['reportable_type'].downcase}. This is the reason:"
    when 'Event::ReportForRequest'
      "'#{notifiable.user.login}' created a report for a request. This is the reason:"
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

  def involved_users
    case event_type
    when 'Event::ReportForComment', 'Event::ReportForPackage', 'Event::ReportForProject', 'Event::ReportForUser', 'Event::ReportForRequest'
      [User.find_by(login: event_payload['reporter'])]
    when 'Event::FavoredDecision', 'Event::ClearedDecision'
      [User.find(event_payload['moderator_id'])]
    when 'Event::AppealCreated'
      [User.find(event_payload['appellant_id'])]
    end
  end
end
