class IssueTrackerNotFoundError < APIError
  setup 'issue_tracker_not_found', 404, 'Issue Tracker not found'
end
