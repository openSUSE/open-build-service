class CleanupNotificationsJob < ApplicationJob
  def perform
    # FIXME: Remove this finder
    NotificationsFinder.new.stale.delete_all
  end
end
