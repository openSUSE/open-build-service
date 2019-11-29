class IssueTracker::IssueTrackerHelper
  attr_reader :tracker, :issue_id
  attr_accessor :url, :summary

  def initialize(issue_id)
    if issue_id.start_with?('CVE-')
      @tracker = 'cve'
      @issue_id = issue_id
    else
      @tracker, @issue_id = issue_id.split('#')
    end
  end

  def valid?
    !@issue_id.nil?
  end

  def to_a
    [@tracker, @issue_id, url, summary]
  end
end
