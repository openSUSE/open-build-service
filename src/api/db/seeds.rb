puts "Seeding architectures table..."
# NOTE: armvXel is actually obsolete (because it never exist as official platform), but kept for compatibility reasons
["aarch64", "armv4l", "armv5l", "armv6l", "armv7l", "armv5el", "armv6el", "armv7el", "armv8el", "hppa", "i586", "i686", "ia64", "local", "mips", "mips32", "mips64", "ppc", "ppc64", "ppc64p7","s390", "s390x", "sparc", "sparc64", "sparc64v", "sparcv8", "sparcv9", "sparcv9v", "x86_64"].each do |arch_name|
  Architecture.find_or_create_by_name :name => arch_name
end
# following our default config
["armv7l", "i586", "x86_64"].each do |arch_name|
  a=Architecture.find_by_name(arch_name)
  a.available=true
  a.recommended=true
  a.save
end

puts "Seeding roles table..."
admin_role      = Role.find_or_create_by_title :title => "Admin", :global => true
user_role       = Role.find_or_create_by_title :title => "User", :global => true
maintainer_role = Role.find_or_create_by_title :title => "maintainer"
downloader_role = Role.find_or_create_by_title :title => 'downloader'
reader_role     = Role.find_or_create_by_title :title => 'reader'
Role.find_or_create_by_title :title => 'bugowner'
Role.find_or_create_by_title :title => 'reviewer'

puts "Seeding users table..."
admin  = User.find_or_create_by_login :login => 'Admin', :email => "root@localhost", :realname => "OBS Instance Superuser", :state => "2", :password => "opensuse", :password_confirmation => "opensuse"
User.find_or_create_by_login :login => "_nobody_", :email => "nobody@localhost", :realname => "Anonymous User", :state => "3", :password => "123456", :password_confirmation => "123456"

puts "Seeding roles_users table..."
RolesUser.find_or_create_by_user_id_and_role_id(admin.id, admin_role.id)

puts "Seeding static_permissions table..."
["status_message_create", "set_download_counters", "download_binaries", "source_access", "access", "global_change_project", "global_create_project", "global_change_package", "global_create_package", "change_project", "create_project", "change_package", "create_package"].each do |sp_title|
  StaticPermission.find_or_create_by_title :title => sp_title
end

puts "Seeding static permissions for admin role in roles_static_permissions table..."
StaticPermission.find(:all).each do |sp|
  admin_role.static_permissions << sp unless admin_role.static_permissions.find_by_id(sp.id)
end

puts "Seeding static permissions for maintainer role in roles_static_permissions table..."
["change_project", "create_project", "change_package", "create_package"].each do |sp_title|
  sp = StaticPermission.find_by_title(sp_title)
  maintainer_role.static_permissions << sp unless maintainer_role.static_permissions.find_by_id(sp.id)
end

puts "Seeding static permissions for reader role in roles_static_permissions table..."
["access", "source_access"].each do |sp_title|
  sp = StaticPermission.find_by_title(sp_title)
  reader_role.static_permissions << sp unless reader_role.static_permissions.find_by_id(sp.id)
end

puts "Seeding static permissions for downloader role in roles_static_permissions table..."
["download_binaries"].each do |sp_title|
  sp = StaticPermission.find_by_title(sp_title)
  downloader_role.static_permissions << sp unless downloader_role.static_permissions.find_by_id(sp.id)
end

puts "Seeding attrib_namespaces table..."
ans = AttribNamespace.find_or_create_by_name :name => "OBS"
ans.attrib_namespace_modifiable_bies.find_or_create_by_bs_user_id(admin.id)

puts "Seeding attrib_types table..."
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "VeryImportantProject", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "UpdateProject", :value_count => 1)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "RejectRequests")
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "ApprovedRequestSource", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "Maintained", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "MaintenanceProject", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "MaintenanceIdTemplate", :value_count => 1)
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "ScreenShots")
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)

at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "OwnerRootProject")
at.attrib_type_modifiable_bies.find_or_create_by_bs_user_id(admin.id)
at.allowed_values << AttribAllowedValue.new( :value => "DisableDevel" )
at.allowed_values << AttribAllowedValue.new( :value => "BugownerOnly" )

at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "RequestCloned", :value_count => 1)
at.attrib_type_modifiable_bies.find_or_create_by_bs_role_id(maintainer_role.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "ProjectStatusPackageFailComment", :value_count => 1)
at.attrib_type_modifiable_bies.find_or_create_by_bs_role_id(maintainer_role.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "InitializeDevelPackage", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_role_id(maintainer_role.id)
at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "BranchTarget", :value_count => 0)
at.attrib_type_modifiable_bies.find_or_create_by_bs_role_id(maintainer_role.id)

at = AttribType.find_or_create_by_attrib_namespace_id_and_name(ans.id, "QualityCategory", :value_count => 1)
at.attrib_type_modifiable_bies.find_or_create_by_bs_role_id(maintainer_role.id)
at.allowed_values << AttribAllowedValue.new( :value => "Stable" )
at.allowed_values << AttribAllowedValue.new( :value => "Testing" )
at.allowed_values << AttribAllowedValue.new( :value => "Development" )
at.allowed_values << AttribAllowedValue.new( :value => "Private" )


puts "Seeding db_project_type table by loading test fixtures"
DbProjectType.find_or_create_by_name("standard")
DbProjectType.find_or_create_by_name("maintenance")
DbProjectType.find_or_create_by_name("maintenance_incident")
DbProjectType.find_or_create_by_name("maintenance_release")

# default repository to link when original one got removed
d = Project.find_or_create_by_name("deleted")
d.repositories.create name: "deleted"

# set default configuration settings
unless Rails.env.test?
Configuration.find_or_create_by_name_and_title_and_description("private", "Open Build Service", <<-EOT
  <p class="description">
    The <a href="http://openbuildservice.org">Open Build Service (OBS)</a>
    is an open and complete distribution development platform that provides a transparent infrastructure for development of Linux distributions, used by openSUSE, MeeGo and other distributions.
    Supporting also Fedora, Debian, Ubuntu, RedHat and other Linux distributions.
  </p>
  <p class="description">
    The OBS is developed under the umbrella of the <a href="http://www.opensuse.org">openSUSE project</a>. Please find further informations on the <a href="http://wiki.opensuse.org/openSUSE:Build_Service">openSUSE Project wiki pages</a>.
  </p>

  <p class="description">
    The Open Build Service developer team is greeting you. In case you use your OBS productive in your facility, please do us a favor and add yourself at <a href="http://wiki.opensuse.org/openSUSE:Build_Service_installations">this wiki page</a>. Have fun and fast build times!
  </p>
EOT
)
end

puts "Seeding issue trackers ..."
IssueTracker.find_or_create_by_name('boost', :description => 'Boost Trac', :kind => 'trac', :regex => 'boost#(\d+)', :url => 'https://svn.boost.org/trac/boost/', :label => 'boost#@@@', :show_url => 'https://svn.boost.org/trac/boost/ticket/@@@')
IssueTracker.find_or_create_by_name('bco', :description => 'Clutter Project Bugzilla', :kind => 'bugzilla', :regex => 'bco#(\d+)', :url => 'http://bugzilla.clutter-project.org/', :label => 'bco#@@@', :show_url => 'http://bugzilla.clutter-project.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('RT', :description => 'CPAN Bugs', :kind => 'other', :regex => 'RT#(\d+)', :url => 'https://rt.cpan.org/', :label => 'RT#@@@', :show_url => 'http://rt.cpan.org/Public/Bug/Display.html?id=@@@')
IssueTracker.find_or_create_by_name('cve', :description => 'CVE Numbers', :kind => 'cve', :regex => '(CVE-\d{4,4}-\d{4,4})', :url => 'http://cve.mitre.org/', :label => '@@@', :show_url => 'http://cve.mitre.org/cgi-bin/cvename.cgi?name=@@@')
IssueTracker.find_or_create_by_name('deb', :description => 'Debian Bugzilla', :kind => 'bugzilla', :regex => 'deb#(\d+)', :url => 'http://bugs.debian.org/', :label => 'deb#@@@', :show_url => 'http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=@@@')
IssueTracker.find_or_create_by_name('fdo', :description => 'Freedesktop.org Bugzilla', :kind => 'bugzilla', :regex => 'fdo#(\d+)', :url => 'https://bugs.freedesktop.org/', :label => 'fdo#@@@', :show_url => 'https://bugs.freedesktop.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('GCC', :description => 'GCC Bugzilla', :kind => 'bugzilla', :regex => 'GCC#(\d+)', :url => 'http://gcc.gnu.org/bugzilla/', :label => 'GCC#@@@', :show_url => 'http://gcc.gnu.org/bugzilla/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bgo', :description => 'Gnome Bugzilla', :kind => 'bugzilla', :regex => 'bgo#(\d+)', :url => 'https://bugzilla.gnome.org/', :label => 'bgo#@@@', :show_url => 'https://bugzilla.gnome.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bio', :description => 'Icculus.org Bugzilla', :kind => 'bugzilla', :regex => 'bio#(\d+)', :url => 'https://bugzilla.icculus.org/', :label => 'bio#@@@', :show_url => 'https://bugzilla.icculus.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bko', :description => 'Kernel.org Bugzilla', :kind => 'bugzilla', :regex => '(?:Kernel|K|bko)#(\d+)', :url => 'https://bugzilla.kernel.org/', :label => 'bko#@@@', :show_url => 'https://bugzilla.kernel.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('kde', :description => 'KDE Bugzilla', :kind => 'bugzilla', :regex => 'kde#(\d+)', :url => 'https://bugs.kde.org/', :label => 'kde#@@@', :show_url => 'https://bugs.kde.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('lp', :description => 'Launchpad.net Bugtracker', :kind => 'launchpad', :regex => 'b?lp#(\d+)', :url => 'https://bugs.launchpad.net/bugs/', :label => 'lp#@@@', :show_url => 'https://bugs.launchpad.net/bugs/@@@')
IssueTracker.find_or_create_by_name('Meego', :description => 'Meego Bugs', :kind => 'bugzilla', :regex => 'Meego#(\d+)', :url => 'https://bugs.meego.com/', :label => 'Meego#@@@', :show_url => 'https://bugs.meego.com/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bmo', :description => 'Mozilla Bugzilla', :kind => 'bugzilla', :regex => 'bmo#(\d+)', :url => 'https://bugzilla.mozilla.org/', :label => 'bmo#@@@', :show_url => 'https://bugzilla.mozilla.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bnc', :description => 'Novell Bugzilla', :enable_fetch => true, :kind => 'bugzilla', :regex => '(?:bnc|BNC)\s*[#:]\s*(\d+)', :url => 'https://bugzilla.novell.com/', :label => 'bnc#@@@', :show_url => 'https://bugzilla.novell.com/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('ITS', :description => 'OpenLDAP Issue Tracker', :kind => 'other', :regex => 'ITS#(\d+)', :url => 'http://www.openldap.org/its/', :label => 'ITS#@@@', :show_url => 'http://www.openldap.org/its/index.cgi/Contrib?id=@@@')
IssueTracker.find_or_create_by_name('i', :description => 'OpenOffice.org Bugzilla', :kind => 'bugzilla', :regex => 'i#(\d+)', :url => 'http://openoffice.org/bugzilla/', :label => 'boost#@@@', :show_url => 'http://openoffice.org/bugzilla/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('fate', :description => 'openSUSE Feature Database', :kind => 'fate', :regex => '[Ff]ate\s+#\s+(\d+)', :url => 'https://features.opensuse.org/', :label => 'fate#@@@', :show_url => 'https://features.opensuse.org/@@@')
IssueTracker.find_or_create_by_name('rh', :description => 'RedHat Bugzilla', :kind => 'bugzilla', :regex => 'rh#(\d+)', :url => 'https://bugzilla.redhat.com/', :label => 'rh#@@@', :show_url => 'https://bugzilla.redhat.com/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bso', :description => 'Samba Bugzilla', :kind => 'bugzilla', :regex => 'bso#(\d+)', :url => 'https://bugzilla.samba.org/', :label => 'bso#@@@', :show_url => 'https://bugzilla.samba.org/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('sf', :description => 'SourceForge.net Tracker', :kind => 'sourceforge', :regex => 'sf#(\d+)', :url => 'http://sf.net/support/', :label => 'sf#@@@', :show_url => 'http://sf.net/support/tracker.php?aid=@@@')
IssueTracker.find_or_create_by_name('Xamarin', :description => 'Xamarin Bugzilla', :kind => 'bugzilla', :regex => 'Xamarin#(\d+)', :url => 'http://bugzilla.xamarin.com/index.cgi', :label => 'Xamarin#@@@', :show_url => 'http://bugzilla.xamarin.com/show_bug.cgi?id=@@@')
IssueTracker.find_or_create_by_name('bxo', :description => 'XFCE Bugzilla', :kind => 'bugzilla', :regex => 'bxo#(\d+)', :url => 'https://bugzilla.xfce.org/', :label => 'bxo#@@@', :show_url => 'https://bugzilla.xfce.org/show_bug.cgi?id=@@@')
