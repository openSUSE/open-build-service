class IssueTracker < ActiveRecord::Base
  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']

  # Provides a list of all regexen for all issue trackers
  def self.regexen
    # TODO: The next line is perfectly cacheable, only needs invalidation if any issue track
    return IssueTracker.all.map {|it| Regexp.new(it.regex)}
  end

  # Generates a URL to display a given issue in the upstream issue tracker
  def show_url_for(issue)
    return show_url.gsub('@@@', issue)
  end

  # Checks if the given issue belongs to this issue tracker
  def matches?(issue)
    return Regexp.new(regex).match(issue)
  end
end
