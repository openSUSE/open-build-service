class AddOtherToIssueTrackerEnum < ActiveRecord::Migration
  def up
    execute "alter table issue_trackers modify column `kind` enum('other', 'bugzilla','cve','fate','trac','launchpad','sourceforge') CHARACTER SET utf8;"
  end
end
