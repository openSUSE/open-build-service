class IssueTrackerWriteToBackendJob < ApplicationJob
  queue_as :quick

  def perform(issue_tracker_id)
    IssueTracker.find(issue_tracker_id).write_to_backend
  end
end
