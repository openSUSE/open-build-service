class IssueTracker::IssueSummary
  attr_reader :issue_tracker, :summary, :issue_id

  def initialize(tracker, issue_id)
    @issue_tracker = IssueTracker.find_by(name: tracker)
    @issue_id = issue_id
  end

  def belongs_bug_to_tracker?
    @issue_tracker && bug.match?(/^#{@issue_tracker.regex}$/)
  end

  def issue_summary
    belongs_bug_to_tracker? ? fetch_issue_summary.gsub(/\\|'/, '') : nil
  end

  private

  def bug
    @issue_id.starts_with?('CVE-') ? @issue_id : "#{@issue_tracker.name}##{@issue_id}"
  end

  def fetch_issue_summary
    issue = find_or_create_by_name_and_tracker
    issue.fetch_updates if issue && issue.summary.blank?
    issue.summary.presence || ''
  end

  def find_or_create_by_name_and_tracker
    Issue.find_or_create_by_name_and_tracker(@issue_id, @issue_tracker.name)
  end
end
