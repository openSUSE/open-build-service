class PermissionUpdate < ActiveRecord::Migration
  def self.up
    # Role#global is false if a role can only be set in context of a project/package
    add_column :roles, :global, :boolean, :default => false
    Role.update_all "global = true"

    # add local maintainer role
    r = Role.create( :title => "maintainer", :global => false )
  
    # update relationship tables
    rename_column :project_user_role_relationships, :bs_role_id, :role_id
    rename_column :package_user_role_relationships, :bs_role_id, :role_id

    ProjectUserRoleRelationship.update_all ["role_id = ?", r.id]
    PackageUserRoleRelationship.update_all ["role_id = ?", r.id]
  end

  def self.down
    #FIXME: only works when previous maintainer.bs_role_id was 1
    ProjectUserRoleRelationship.update_all ["role_id = ?", 1]
    PackageUserRoleRelationship.update_all ["role_id = ?", 1]

    rename_column :project_user_role_relationships, :role_id, :bs_role_id
    rename_column :package_user_role_relationships, :role_id, :bs_role_id
    
    Role.delete_all ["title = ?", 'maintainer']
    
    remove_column :roles, :global
  end
end
