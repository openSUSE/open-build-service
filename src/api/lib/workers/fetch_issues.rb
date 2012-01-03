class FetchIssues

  def perform
    c = IssueTracker.new
    c.fetch_issues()
  end

end
