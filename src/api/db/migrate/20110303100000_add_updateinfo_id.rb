class AddUpdateinfoId < ActiveRecord::Migration
  def self.up
    add_column :maintenance_incidents, :updateinfo_id, :integer
    add_column :maintenance_incidents, :incident_id, :integer
  end

  def self.down
    remove_column :maintenance_incidents, :updateinfo_id
    remove_column :maintenance_incidents, :incident_id
  end
end
