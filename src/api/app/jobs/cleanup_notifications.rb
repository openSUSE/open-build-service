class CleanupNotifications < ApplicationJob
  def perform
    Notifications::RssFeedItem.cleanup
  end
end
