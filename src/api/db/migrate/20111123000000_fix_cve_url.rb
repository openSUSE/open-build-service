class FixCveUrl < ActiveRecord::Migration

  def self.up
    i = IssueTracker.find_by_name('cve')
    i.delete if i
    IssueTracker.find_or_create_by_name('cve', :description => 'CVE Numbers', :kind => 'cve', :regex => 'CVE-\d{4,4}-\d{4,4}', :url => 'http://cve.mitre.org/', :show_url => 'http://cve.mitre.org/cgi-bin/cvename.cgi?name=@@@')
  end

  def self.down
    i = IssueTracker.find_by_name('cve')
    i.delete if i
    IssueTracker.find_or_create_by_name('cve', :description => 'CVE Numbers', :kind => 'cve', :regex => 'CVE-\d{4,4}-\d{4,4}', :url => 'http://www.cvedetails.com/', :show_url => 'http://www.cvedetails.com/cve/@@@')
  end

end

