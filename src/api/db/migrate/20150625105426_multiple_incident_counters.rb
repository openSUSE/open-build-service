
class TempMI < ActiveRecord::Base
  self.table_name = 'maintenance_incidents'
end

class MultipleIncidentCounters < ActiveRecord::Migration
  def self.up
   create_table :incident_updateinfo_counter_values do |t|
     t.references :updateinfo_counter, null: false
     t.references :project,     null: false
     t.integer    :value,       null: false
     t.datetime   :released_at, null: false
   end
   add_index :incident_updateinfo_counter_values, [:updateinfo_counter_id, :project_id], :name => "uniq_id_index"
   execute("alter table incident_updateinfo_counter_values add foreign key (project_id) references projects(id)")

   rename_table  :updateinfo_counter, :updateinfo_counters

   TempMI.all.each do |mi|
     value = mi.counter
     next unless value

     mp = mi.maintenance_db_project

     # there could have been just one so far
     uc = UpdateinfoCounter.find_by_maintenance_db_project( mp ).first

     IncidentUpdateinfoCounterValue.create(updateinfo_counter: uc, project: mp, value: value)
   end

   remove_column :maintenance_incidents, :counter
   remove_column :maintenance_incidents, :name
  end

  def self.down
    drop_table   :incident_updateinfo_counter_values
    add_column   :maintenance_incidents, :counter, :integer
    add_column   :maintenance_incidents, :name, :string
    rename_table :updateinfo_counters, :updateinfo_counter
  end
end
