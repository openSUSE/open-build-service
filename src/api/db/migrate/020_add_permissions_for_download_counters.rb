class AddPermissionsForDownloadCounters < ActiveRecord::Migration


  def self.up
    StaticPermission.create :title => "set_download_counters"
    execute "INSERT INTO `roles_static_permissions` VALUES (1,6,NOW())"
  end


  def self.down
    sp = StaticPermission.find_by_title( "set_download_counters" )
    sp.destroy if sp
    execute "DELETE FROM `roles_static_permissions` WHERE (role_id=1 AND static_permission_id=6)"
  end


end
