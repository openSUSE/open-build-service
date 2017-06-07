class UseRailsEnumsIssueTrackerTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:issue_trackers) do |t|
      t.column :new_kind, :integer, limit: 2, null: false
    end

    IssueTracker.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      IssueTracker.connection.execute("UPDATE issue_trackers SET new_kind='#{index}' WHERE kind='#{IssueTracker.kinds.key(index)}'")
    end

    remove_column :issue_trackers, :kind
    rename_column :issue_trackers, :new_kind, :kind
  end

  def down
    change_table(:issue_trackers) do |t|
      t.column :new_kind, "ENUM('other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge', 'github')", null: false
    end

    IssueTracker.kinds.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      IssueTracker.connection.execute("UPDATE issue_trackers SET new_kind='#{IssueTracker.kinds.key(index)}' WHERE kind='#{index}'")
    end

    remove_column :issue_trackers, :kind
    rename_column :issue_trackers, :new_kind, :kind

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
