class MakeReportsReportablesNullable < ActiveRecord::Migration[7.0]
  def change
    change_column_null :reports, :reportable_type, true
    change_column_null :reports, :reportable_id, true
  end
end
