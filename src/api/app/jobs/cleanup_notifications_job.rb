class CleanupNotificationsJob < ApplicationJob
  def perform
    Notification.stale.in_batches.destroy_all
  end
end
