## This was found by a script
class Addmoreindexes < ActiveRecord::Migration
  def self.up
      
     add_index :release_targets, :target_repository_id
     add_index :attrib_namespace_modifiable_bies, :attrib_namespace_id
     add_index :downloads, :db_project_id
     add_index :downloads, :architecture_id
     add_index :maintenance_incidents, :db_project_id
     add_index :maintenance_incidents, :maintenance_db_project_id
  end

  def self.down
     remove_index :release_targets, :target_repository_id
     remove_index :attrib_namespace_modifiable_bies, :attrib_namespace_id
     remove_index :downloads, :db_project_id
     remove_index :downloads, :architecture_id
     remove_index :maintenance_incidents, :db_project_id
     remove_index :maintenance_incidents, :maintenance_db_project_id
  end

end
