class AddDatetimeIndexToLogEntries < ActiveRecord::Migration
  def change
    add_index :project_log_entries, :datetime
  end
end
