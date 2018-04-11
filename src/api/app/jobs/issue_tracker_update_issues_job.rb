# frozen_string_literal: true

class IssueTrackerUpdateIssuesJob < ApplicationJob
  queue_as :issuetracking

  def perform(issue_tracker_id)
    IssueTracker.find(issue_tracker_id).update_issues
  end
end
