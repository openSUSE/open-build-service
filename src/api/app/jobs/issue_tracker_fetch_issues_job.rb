class IssueTrackerFetchIssuesJob < ApplicationJob
  queue_as :issuetracking

  def perform(issue_tracker_id)
    IssueTracker.find_by(id: issue_tracker_id).try(:fetch_issues)
  end
end
