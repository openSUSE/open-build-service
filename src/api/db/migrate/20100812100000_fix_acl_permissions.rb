class FixAclPermissions < ActiveRecord::Migration
  def self.up
    reader     = Role.find_by_title 'reader'
    maintainer = Role.find_by_title 'maintainer'
    downloader = Role.find_by_title 'downloader'

    sourceperm = StaticPermission.find_by_title('source_access')
    [maintainer,reader].each do |role|
      role.static_permissions << sourceperm
    end

    privperm = StaticPermission.find_by_title('private_view')
    [maintainer,reader,downloader].each do |role|
      role.static_permissions << privperm
    end

    downloadperm = StaticPermission.find_by_title('download_binaries')
    [maintainer,downloader].each do |role|
      role.static_permissions << downloadperm
    end
  end

  def self.down
  end
end
