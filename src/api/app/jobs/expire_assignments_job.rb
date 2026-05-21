class ExpireAssignmentsJob < ApplicationJob
  queue_as :default

  def perform
    Assignment.where(created_at: ...1.day.ago).delete_all
  end
end
