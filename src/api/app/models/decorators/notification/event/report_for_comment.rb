class Decorators::Notification::Event::ReportForComment < Decorators::Notification::Common
  def description_text
    "'#{notification.notifiable.user.login}' created a report for a comment from #{notification.event_payload['commenter']}. This is the reason:"
  end

  def notifiable_link_text(_helpers)
    if Comment.exists?(notification.event_payload['reportable_id'])
      'Report for a comment'
    else
      'Report for a deleted comment'
    end
  end
end
