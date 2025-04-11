class AddReporterToReports < ActiveRecord::Migration[7.1]
  def change
    add_reference :reports, :reporter, foreign_key: { to_table: :users }, type: :int
  end
end
