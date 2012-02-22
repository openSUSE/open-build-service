class UpdateIssuesJob

  def initialize
  end

  def perform
    IssueTracker.find(:all).each do |t|
      next unless t.enable_fetch
      t.update_issues()
    end
  end

end


