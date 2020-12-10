class AddUniqueIndexNameToStatusChecksTable < ActiveRecord::Migration[6.0]
  def change
    add_index :status_checks, [:name, :status_reports_id], unique: true
  end
end
