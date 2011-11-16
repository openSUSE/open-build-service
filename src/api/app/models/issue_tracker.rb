class IssueTracker < ActiveRecord::Base
  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']
end
