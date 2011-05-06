class CreateUpdateinfoCounter < ActiveRecord::Migration
  def self.up
    create_table :updateinfo_counter do |t|
      t.integer :maintenance_db_project_id
      t.integer :day
      t.integer :month
      t.integer :year
      t.integer :counter, :default => 0
    end
    create_table :incident_counter do |t|
      t.integer :maintenance_db_project_id
      t.integer :counter, :default => 0
    end

    remove_column :maintenance_incidents, :year
    remove_column :maintenance_incidents, :month
    remove_column :maintenance_incidents, :day
  end

  def self.down
    drop_table :updateinfo_counter
    drop_table :incident_counter

    add_column :maintenance_incidents, :year,  :integer
    add_column :maintenance_incidents, :month, :integer
    add_column :maintenance_incidents, :day,   :integer
  end
end
