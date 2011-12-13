
class FetchIssues

  def perform
    c = IssueTrackerController.new
    c.fetch_issues()
  end

end

