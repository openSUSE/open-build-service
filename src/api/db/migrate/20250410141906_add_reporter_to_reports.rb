class AddReporterToReports < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_reference :reports, :reporter, foreign_key: { to_table: :users }, type: :int
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
