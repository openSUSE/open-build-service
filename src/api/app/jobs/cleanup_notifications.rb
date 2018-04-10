# frozen_string_literal: true
class CleanupNotifications < ApplicationJob
  def perform
    Notification::RssFeedItem.cleanup
  end
end
