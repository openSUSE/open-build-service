class AddNoNullConstraintToReportReporters < ActiveRecord::Migration[7.1]
  def change
    change_column_null :reports, :reporter_id, false
  end
end
