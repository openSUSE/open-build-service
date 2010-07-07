    Architecture.create :name => "armv4l"
    Architecture.create :name => "armv5el"
    Architecture.create :name => "armv6el"
    Architecture.create :name => "armv7el"
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

    Role.create :title => "Admin"
    Role.create :title => 'bugowner'
    Role.create :title => 'downloader'
    Role.create :title => "maintainer"
    Role.create :title => 'reader'
    Role.create :title => 'reviewer'
    Role.create :title => "User"

    admin  = User.create :login => 'Admin', :email => "root@localhost", :realname => "OBS Instance Superuser", :state => "2", :password => "opensuse", :password_confirmation => "opensuse"
    nobody = User.create :login => "_nobody_", :email => "nobody@localhost", :realname => "Anonymous User", :state => "3", :password => "123456", :password_confirmation => "123456"

    p={}
    p[:user] = admin
    ans=AttribNamespace.create :name => "OBS"
    ans.attrib_namespace_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "VeryImportantProject", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "UpdateProject", :value_count=>1 )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "Maintained", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "ScreenShots" )
    at.attrib_type_modifiable_bies.create(p)
