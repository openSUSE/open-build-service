class IssueTrackerWriteToBackendJob < ApplicationJob
  def perform(issue_tracker_id)
    IssueTracker.find(issue_tracker_id).write_to_backend
  end
end
