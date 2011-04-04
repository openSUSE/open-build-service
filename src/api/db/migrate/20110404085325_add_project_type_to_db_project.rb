class AddProjectTypeToDbProject < ActiveRecord::Migration
  def self.up
    add_column :db_projects, :type_id, :int
  end

  def self.down
    remove_column :db_projects, :type_id
  end
end
