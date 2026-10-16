class ChangeProjectLogEntryAdditionalInfoToMediumtext < ActiveRecord::Migration[8.1]
  def up
    safety_assured { change_column :project_log_entries, :additional_info, :mediumtext }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
