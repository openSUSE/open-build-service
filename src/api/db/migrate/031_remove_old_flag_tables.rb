class RemoveOldFlagTables < ActiveRecord::Migration
  
  
  def self.up
    save_table_to_fixture('disabled_repos')
    
    save_table_to_fixture('flag_types')
    
    save_table_to_fixture('flag_group_types')
    
    save_table_to_fixture('project_flags')
    
    save_table_to_fixture('project_flag_groups')
    
    save_table_to_fixture('package_flags')
    
    save_table_to_fixture('package_flag_groups')
    
    #drop old flag tables
    drop_table :disabled_repos
    drop_table :flag_types
    drop_table :flag_group_types
    drop_table :project_flags
    drop_table :project_flag_groups
    drop_table :package_flags
    drop_table :package_flag_groups
    
  end


  def self.down
    AddProjectBuildFlags.up
    CreateDisabledRepos.up
    
    #restore_table_from_fixture('timesheets')
    restore_table_from_fixture('disabled_repos')
    
    restore_table_from_fixture('flag_types')
    
    restore_table_from_fixture('flag_group_types')
    
    restore_table_from_fixture('project_flags')
    
    restore_table_from_fixture('project_flag_groups')
    
    restore_table_from_fixture('package_flags')
    
    restore_table_from_fixture('package_flag_groups') 
       
  end


end
