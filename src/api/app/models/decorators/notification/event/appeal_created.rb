class Decorators::Notification::Event::AppealCreated < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.appellant.login}' appealled the decision for the following reason:"
  end

  def notifiable_link_text(_helpers)
    "Appealed the decision for a report of #{notification.notifiable.decision.moderator.login}"
  end

  def notifiable_link_path
    Rails.application.routes.url_helpers.appeal_path(notification.notifiable)
  end

  def avatar_objects
    [User.find(notification.event_payload['appellant_id'])]
  end
end
