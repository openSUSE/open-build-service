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

  def bug
    @issue_id.starts_with?('CVE-') ? @issue_id : @tracker + '#' + @issue_id
  end

  def valid?
    !@issue_id.nil?
  end

  def cve?
    @tracker == 'cve'
  end

  def not_cve?
    !cve?
  end

  def to_a
    [@tracker, @issue_id, url, summary]
  end
end
