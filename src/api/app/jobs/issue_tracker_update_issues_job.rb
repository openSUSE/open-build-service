class IssueTrackerUpdateIssuesJob < ApplicationJob
  queue_as :issuetracking

  def perform(issue_tracker_id)
    IssueTracker.find_by_id(issue_tracker_id).try(:update_issues)
  end
end
