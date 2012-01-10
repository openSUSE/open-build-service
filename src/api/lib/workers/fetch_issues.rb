class FetchIssues

  def perform
    IssueTracker.find(:all).each do |t|
      t.fetch_issues()
    end
  end

end
