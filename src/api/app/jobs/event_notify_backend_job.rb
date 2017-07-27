class EventNotifyBackendJob < ApplicationJob
  def perform
    Event::Base.not_in_queue.find_each(&:notify_backend)
  end
end
