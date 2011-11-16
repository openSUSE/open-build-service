
class AlterIssueTrackers < ActiveRecord::Migration
  def self.up
    # Instead of identyfing issue trackers by a set of acronyms, use a regex.
    # This allows to match issues like 'CVE-2011-1234' and 'bnc#1234'.
    change_table :issue_trackers do |t|
      t.column :kind, "ENUM('bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge')", :after => :name
      t.string :description, :after => :kind
      t.string :regex, :null => false
      # Can't use ':type', it's a Ruby reserved word that doesn't produce errors but silently breaks:
    end

    # Acronyms aren't helpful anymore, the API will provide a route "get me the issue tracker for bug 'bnc#1234'"
    drop_table :issue_tracker_acronyms

    # Clean up table, so that 'rake db:seed' can populate it correctly
    execute "DELETE FROM issue_trackers;"
    print "PLEASE RUN 'rake db:seed' AFTERWARDS!\n"
  end

  def self.down
    create_table :issue_tracker_acronyms do |t|
      t.integer :issue_tracker_id
      t.string :name, :null => false
      t.index :name
    end

    change_table :issue_trackers do |t|
      t.remove :description
      t.remove :regex
      t.remove :kind
    end
  end
end
