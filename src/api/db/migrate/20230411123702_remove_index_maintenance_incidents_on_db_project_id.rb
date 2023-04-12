class RemoveIndexMaintenanceIncidentsOnDbProjectId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'maintenance_incidents', 'db_project_id', name: 'index_maintenance_incidents_on_db_project_id'
  end
end
