class SwitchNotNullConstraintFromUserToReporterForReports < ActiveRecord::Migration[7.1]
  def change
    change_column_null :reports, :user_id, true
    change_column_null :reports, :reporter_id, false
  end
end
