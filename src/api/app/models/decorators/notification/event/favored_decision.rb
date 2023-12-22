class Decorators::Notification::Event::FavoredDecision < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.moderator.login}' decided to favor the report. This is the reason:"
  end
end
