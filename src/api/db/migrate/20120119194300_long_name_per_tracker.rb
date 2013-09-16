class LongNamePerTracker < ActiveRecord::Migration
  def self.up
    self.transaction do
      remove_column :issues, :long_name
      add_column :issue_trackers, :long_name, :string

      IssueTracker.find(:all).each do |t|
        long_name="#{t.name}#%s"
        long_name="%s" if t.name=="cve"

        # do not using the model, because we have changed it
        execute("update issue_trackers SET long_name='#{long_name}' where name='#{t.name}'")
      end
      

      execute("alter table issue_trackers modify long_name text NOT NULL")

    end
  end

  def self.down
    add_column :issues, :long_name, :string
    remove_column :issue_trackers, :long_name
  end
end
