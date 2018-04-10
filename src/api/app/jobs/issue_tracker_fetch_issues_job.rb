# frozen_string_literal: true

class IssueTrackerFetchIssuesJob < ApplicationJob
  queue_as :issuetracking

  def perform(issue_tracker_id)
    IssueTracker.find(issue_tracker_id).fetch_issues
  end
end
