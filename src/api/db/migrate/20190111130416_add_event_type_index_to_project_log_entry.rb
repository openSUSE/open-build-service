class AddEventTypeIndexToProjectLogEntry < ActiveRecord::Migration[5.2]
  def change
    add_index :project_log_entries, %i[project_id event_type]
  end
end
