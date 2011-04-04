Architecture.create :name => "armv4l"
Architecture.create :name => "armv5el"
Architecture.create :name => "armv6el"
Architecture.create :name => "armv7el"
Architecture.create :name => "armv7hl"
Architecture.create :name => "armv8el"
Architecture.create :name => "hppa"
Architecture.create :name => "i586"
Architecture.create :name => "i686"
Architecture.create :name => "ia64"
Architecture.create :name => "local"
Architecture.create :name => "mips"
Architecture.create :name => "mips32"
Architecture.create :name => "mips64"
Architecture.create :name => "ppc"
Architecture.create :name => "ppc64"
Architecture.create :name => "s390"
Architecture.create :name => "s390x"
Architecture.create :name => "sparc"
Architecture.create :name => "sparc64"
Architecture.create :name => "sparc64v"
Architecture.create :name => "sparcv8"
Architecture.create :name => "sparcv9"
Architecture.create :name => "sparcv9v"
Architecture.create :name => "x86_64"

admin_role = Role.create :title => "Admin", :global => true
user_role  = Role.create :title => "User", :global => true
maintainer_role = Role.create :title => "maintainer"
downloader_role = Role.create :title => 'downloader'
reader_role     = Role.create :title => 'reader'
Role.create :title => 'bugowner'
Role.create :title => 'reviewer'

admin  = User.create :login => 'Admin', :email => "root@localhost", :realname => "OBS Instance Superuser", :state => "2", :password => "opensuse", :password_confirmation => "opensuse"
nobody = User.create :login => "_nobody_", :email => "nobody@localhost", :realname => "Anonymous User", :state => "3", :password => "123456", :password_confirmation => "123456"

RolesUser.create :user => admin, :role => admin_role
RolesUser.create :user => admin, :role => user_role

StaticPermission.create :title => "status_message_create"
StaticPermission.create :title => "set_download_counters"
StaticPermission.create :title => "download_binaries"
StaticPermission.create :title => "source_access"
StaticPermission.create :title => "access"
StaticPermission.create :title => "global_change_project"
StaticPermission.create :title => "global_create_project"
StaticPermission.create :title => "global_change_package"
StaticPermission.create :title => "global_create_package"
StaticPermission.create :title => "change_project"
StaticPermission.create :title => "create_project"
StaticPermission.create :title => "change_package"
StaticPermission.create :title => "create_package"

StaticPermission.find(:all).each do |sp|
  admin_role.static_permissions << sp
end
maintainer_role.static_permissions << StaticPermission.find_by_title('change_project')
maintainer_role.static_permissions << StaticPermission.find_by_title('create_project')
maintainer_role.static_permissions << StaticPermission.find_by_title('change_package')
maintainer_role.static_permissions << StaticPermission.find_by_title('create_package')
reader_role.static_permissions     << StaticPermission.find_by_title('access')
reader_role.static_permissions     << StaticPermission.find_by_title('source_access')
downloader_role.static_permissions << StaticPermission.find_by_title('download_binaries')

p={}
p[:user] = admin
pm={}
pm[:role] = maintainer_role
ans=AttribNamespace.create :name => "OBS"
ans.attrib_namespace_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "VeryImportantProject", :value_count=>0 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "UpdateProject", :value_count=>1 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "RejectRequests", :value_count=>1 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "Maintained", :value_count=>0 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceProject", :value_count=>0 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceVersion", :value_count=>1 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceIdTemplate", :value_count=>1 )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "ScreenShots" )
at.attrib_type_modifiable_bies.create(p)
at=AttribType.create( :attrib_namespace => ans, :name => "RequestCloned", :value_count=>1 )
at.attrib_type_modifiable_bies.create(pm)
at=AttribType.create( :attrib_namespace => ans, :name => "ProjectStatusPackageFailComment", :value_count=>1 )
at.attrib_type_modifiable_bies.create(pm)
at=AttribType.create( :attrib_namespace => ans, :name => "InitializeDevelPackage", :value_count=>0 )
at.attrib_type_modifiable_bies.create(pm)
