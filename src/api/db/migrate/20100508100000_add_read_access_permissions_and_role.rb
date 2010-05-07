class AddReadAccessPermissionsAndRole < ActiveRecord::Migration
  def self.up
    perm = StaticPermission.create :title => 'read_access'
    maint = Role.find_by_title 'maintainer'
    downl = Role.find_by_title 'downloader'
    reade = Role.create :title => 'reader'

    [maint,downl,reade].each do |role|
      role.static_permissions << perm
    end
  end

  def self.down
    perm = StaticPermission.find_by_title('read_access')
    if perm
      perm.destroy
    end
  end
end
