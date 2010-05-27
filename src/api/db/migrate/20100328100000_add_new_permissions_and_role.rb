class AddNewPermissionsAndRole < ActiveRecord::Migration
  def self.up
    sourceperm   = StaticPermission.create :title => 'source_access'
    privperm   = StaticPermission.create :title => 'private_view'
    reader     = Role.create :title => 'reader'
    maintainer = Role.find_by_title 'maintainer'

    [maintainer,reader].each do |role|
      role.static_permissions << sourceperm
    end
    maintainer.static_permissions << privperm
  end

  def self.down
    perm = StaticPermission.find_by_title('source_access')
    if perm
      perm.destroy
    end
    perm = StaticPermission.find_by_title('private_view')
    if perm
      perm.destroy
    end
  end
end
