class ExpireAssignmentsJob < ApplicationJob
  queue_as :default

  def perform
    Assignment.where(created_at: ...1.day.ago).destroy_all
  end
end
