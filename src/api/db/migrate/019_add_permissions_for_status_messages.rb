class AddPermissionsForStatusMessages < ActiveRecord::Migration


  def self.up
    StaticPermission.create :title => "status_message_create"
    execute "INSERT INTO `roles_static_permissions` VALUES (1,5,NOW())"
  end


  def self.down
    StaticPermission.find_by_title( "status_message_create" ).destroy
    execute "DELETE FROM `roles_static_permissions` WHERE (role_id=1 AND static_permission_id=5)"
  end


end
