class Decorators::Notification::Event::ClearedDecision < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.moderator.login}' decided to clear the report. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    # All reports should point to the same reportable. We will take care of that here:
    # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
    # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
    "Cleared #{notification.notifiable.reports.first.reportable&.class&.name} Report".squish
  end

  def notifiable_link_path
    reportable = notification.notifiable.reports.first.reportable
    link_for_reportables(reportable)
  end

  def avatar_objects
    comments = notification.notifiable.commentable.comments
    comments.select { |comment| comment.updated_at >= notification.unread_date }.map(&:user).uniq
  end
end
