class CreateProjectLogEntries < ActiveRecord::Migration
  def up
    create_table :project_log_entries do |t|
      t.references :project
      t.string     :user_name
      t.string     :package_name
      t.references :bs_request
      t.datetime   :datetime
      t.string     :event_type
      t.text       :additional_info
    end

    # Only project_id is a real foreign key
    execute("alter table project_log_entries add foreign key (project_id) references projects(id)")
    add_index :project_log_entries, :user_name
    add_index :project_log_entries, :package_name
    add_index :project_log_entries, :bs_request_id
    add_index :project_log_entries, :event_type

    # To track which events are already in the new log
    # (once again, not a real foreign key, but more meaningful than a boolean)
    add_column :events, :project_logged, :boolean, default: false
    add_index :events, :project_logged
    add_index :events, :eventtype
    add_index :events, :created_at
  end

  def down
    drop_table :project_log_entries
    remove_column :events, :project_logged
    remove_index :events, :eventtype
    remove_index :events, :created_at
  end
end
