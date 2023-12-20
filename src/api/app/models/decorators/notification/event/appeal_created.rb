class Decorators::Notification::Event::AppealCreated < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.appellant.login}' appealled the decision for the following reason:"
  end

  def notifiable_link_text(_helpers)
    "Appealed the decision for a report of #{notification.notifiable.decision.moderator.login}"
  end
end
