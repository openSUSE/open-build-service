class Decorators::Notification::Event::FavoredDecision < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.moderator.login}' decided to favor the report. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    # All reports should point to the same reportable. We will take care of that here:
    # https://trello.com/c/xrjOZGa7/45-ensure-all-reports-of-a-decision-point-to-the-same-reportable
    # This reportable won't be nil once we fix this: https://trello.com/c/vPDiLjIQ/66-prevent-the-creation-of-reports-without-reportable
    "Favored #{notification.notifiable.reports.first.reportable&.class&.name} Report".squish
  end
end
