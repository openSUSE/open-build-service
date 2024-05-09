class CleanupNotificationsJob < ApplicationJob
  def perform
    Notification.stale.delete_all
  end
end
