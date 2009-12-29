class FlagIndexProjects < ActiveRecord::Migration
  def self.up
    add_index :flags, ['db_project_id', 'type']
  end

  def self.down
    remove_index :flags, :column => ['db_project_id', 'type'] 
  end
end
