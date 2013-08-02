class DropOldRelationships < ActiveRecord::Migration
  def change 
    drop_table :package_user_role_relationships
    drop_table :package_group_role_relationships
    drop_table :project_user_role_relationships
    drop_table :project_group_role_relationships
  end
end
