class AddJiraIssueKind < ActiveRecord::Migration[4.2]
  def self.up
    execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github','jira') not null;"
  end

  def self.down
    execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github') not null;"
  end
end
