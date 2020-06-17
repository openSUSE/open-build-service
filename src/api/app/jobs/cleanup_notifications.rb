class CleanupNotifications < ApplicationJob
  def perform
    Notification.cleanup
  end
end
