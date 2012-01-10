class UpdateIssuesJob

  def initialize
  end

  def perform
    IssueTracker.find(:all).each do |t|
      t.update_issues()
    end
  end

end


