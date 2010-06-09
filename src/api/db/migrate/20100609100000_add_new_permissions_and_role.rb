class AddNewPermissionsAndRole < ActiveRecord::Migration
  def self.up
    reader = Role.find_by_title 'reader'
    if reader.nil?
      reader = Role.create :title => 'reader'
    end
    maintainer = Role.find_by_title 'maintainer'

    sourceperm = StaticPermission.find_by_title('source_access')
    if sourceperm.nil?
      sourceperm = StaticPermission.create :title => 'source_access'
      [maintainer,reader].each do |role|
        role.static_permissions << sourceperm
      end
    end
    privperm = StaticPermission.find_by_title('private_view')
    if privperm.nil?
      privperm   = StaticPermission.create :title => 'private_view'      
      maintainer.static_permissions << privperm
    end
    accessperm = StaticPermission.find_by_title('access')
    if accessperm.nil?
      accessperm = StaticPermission.create :title => 'access'
      maintainer.static_permissions << accessperm
    end
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
    perm = StaticPermission.find_by_title('access')
    if perm
      perm.destroy
    end
  end
end
