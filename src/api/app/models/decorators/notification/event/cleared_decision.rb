class Decorators::Notification::Event::ClearedDecision < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.moderator.login}' decided to clear the report. This is the reason:"
  end
end
