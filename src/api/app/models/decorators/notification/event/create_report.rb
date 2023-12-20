class Decorators::Notification::Event::CreateReport < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a #{notification.event_payload['reportable_type'].downcase}. This is the reason:"
  end

  # TODO: Remove `Event::CreateReport` after all existing records are migrated to the new STI classes
  def notifiable_link_text(_helpers)
    "Report for a #{notification.event_payload['reportable_type']}"
  end
end
