class AdaptCveTracker < ActiveRecord::Migration

  def up
    t=IssueTracker.find_by_name('cve')
    t.regex='(?:cve|CVE)-(\d\d\d\d-\d+)'
    t.label="CVE-@@@"
    t.save
    Delayed::Worker.delay_jobs = true
    IssueTracker.write_to_backend

    t.issues.each do |i|
      i.name.gsub!(/^CVE-/,'')
      i.name.gsub!(/^cve-/,'')
      i.save
    end
  end

  def down
    t=IssueTracker.find_by_name('cve')
    t.regex='(CVE-\d\d\d\d-\d+)'
    t.label="@@@"
    t.save
    Delayed::Worker.delay_jobs = true
    IssueTracker.write_to_backend

    t.issues.each do |i|
      i.name = "CVE-" + i.name
      i.save
    end
  end

end
