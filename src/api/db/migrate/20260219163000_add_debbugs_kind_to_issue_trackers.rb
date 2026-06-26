class AddDebbugsKindToIssueTrackers < ActiveRecord::Migration[7.2]
  def self.up
    safety_assured { execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github','jira','debbugs') not null;" }
  end

  def self.down
    safety_assured { execute "alter table issue_trackers modify column kind enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github','jira') not null;" }
  end
end
