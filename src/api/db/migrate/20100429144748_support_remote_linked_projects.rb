class SupportRemoteLinkedProjects < ActiveRecord::Migration
  def self.up
    add_column :linked_projects, :linked_remote_project_name, :string
    change_column :linked_projects, :linked_db_project_id, :integer, :null => true
  end

  def self.down
    remove_column :linked_projects, :linked_remote_project_name
    change_column :linked_projects, :linked_db_project_id, :integer, :null => false
  end
end
