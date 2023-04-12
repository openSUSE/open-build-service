class AddMaintenanceIncidentsDbProjectIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :maintenance_incidents, %w[db_project_id], name: :index_maintenance_incidents_db_project_id, unique: true
  end
end
