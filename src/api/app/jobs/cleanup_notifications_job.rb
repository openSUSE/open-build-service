class CleanupNotificationsJob < ApplicationJob
  def perform
    NotificationsFinder.new.stale.delete_all
  end
end
