class Decorators::Notification::Event::AppealCreated < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.appellant.login}' appealled the decision for the following reason:"
  end
end
