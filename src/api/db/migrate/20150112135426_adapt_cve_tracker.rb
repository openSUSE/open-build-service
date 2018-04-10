# frozen_string_literal: true
class AdaptCveTracker < ActiveRecord::Migration[4.2]
  def up
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('cve')
      t.regex = '(?:cve|CVE)-(\d\d\d\d-\d+)'
      t.label = 'CVE-@@@'
      t.show_url = 'http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-@@@'
      t.save
      Delayed::Worker.delay_jobs = true
      # trigger IssueTracker delayed jobs
      IssueTracker.first.try(:save)

      t.issues.each do |i|
        i.name.gsub!(/^CVE-/, '')
        i.name.gsub!(/^cve-/, '')
        i.save
      end
    end
  end

  def down
    ActiveRecord::Base.transaction do
      t = IssueTracker.find_by_name('cve')
      t.regex = '(CVE-\d\d\d\d-\d+)'
      t.label = '@@@'
      t.show_url = 'http://cve.mitre.org/cgi-bin/cvename.cgi?name=@@@'
      t.save
      Delayed::Worker.delay_jobs = true
      # trigger IssueTracker delayed jobs
      IssueTracker.first.try(:save)

      t.issues.each do |i|
        i.name = 'CVE-' + i.name
        i.save
      end
    end
  end
end
