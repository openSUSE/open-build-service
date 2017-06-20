class CleanupNotifications < ApplicationJob
  def perform
    Notification::RssFeedItem.cleanup
  end
end
