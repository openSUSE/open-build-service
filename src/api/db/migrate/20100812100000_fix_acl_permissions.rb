class FixAclPermissions < ActiveRecord::Migration
  def self.up
    #reader     = Role.find_by_title 'reader'
    #maintainer = Role.find_by_title 'maintainer'
    #downloader = Role.find_by_title 'downloader'

    #sourceperm   = StaticPermission.find_by_title('source_access')
    #privperm     = StaticPermission.find_by_title('private_view')
    #downloadperm = StaticPermission.find_by_title('download_binaries')
    #accessperm   = StaticPermission.find_by_title('access')

    #reader.static_permissions     << [sourceperm, privperm]
    #downloader.static_permissions << [downloadperm, privperm]
    #maintainer.static_permissions << [accessperm, downloadperm, sourceperm, privperm]
    #maintainer.static_permissions << [accessperm, downloadperm, privperm]

  end

  def self.down
  end
end
