class CleanupNotifications < ApplicationJob
  def perform
    Notification::RssFeedItem.cleanup
    Notification::DailyEmailItem.cleanup
  end
end
