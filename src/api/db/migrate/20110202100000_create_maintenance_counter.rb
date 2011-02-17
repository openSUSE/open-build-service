class CreateMaintenanceCounter < ActiveRecord::Migration
  def self.up
    create_table :maintenance_incidents do |t|
      t.integer :db_project_id
      t.integer :maintenance_db_project_id
      t.integer :request
      t.integer :day
      t.integer :month
      t.integer :year
    end
  end

  def self.down
    drop_table :maintenance_incidents
  end
end
