class RemoveRequestFromMaintenanceIncident < ActiveRecord::Migration
  def self.up
    remove_column :maintenance_incidents, :request
  end

  def self.down
    add_column :maintenance_incidents, :request, :integer
  end
end
