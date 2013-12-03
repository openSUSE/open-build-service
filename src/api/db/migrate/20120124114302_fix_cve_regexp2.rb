class FixCveRegexp2 < ActiveRecord::Migration
  def self.up
    t=IssueTracker.find_by_name('cve')
    t.regex='(CVE-\d\d\d\d-\d\d\d\d)' # the only way how it works in ruby AND perl
    t.save
    IssueTracker.write_to_backend
  end

  def self.down
    t=IssueTracker.find_by_name('cve')
    t.regex="CVE-\d{4,4}-\d{4,4}"
    t.save
    IssueTracker.write_to_backend
  end
end
