# This class represents a "static permission" dataset in the database. A 
# static permission basically only is a string that can be attached to a
# role. You can then check for it being assigned to a role in your application
# code.
#
# The StaticPermission ActiveRecord class mixes in the 
# "ActiveRbacMixins::StaticPermissionMixins::*" modules. These modules contain the actual 
# implementation. It is kept there so you can easily provide your own model 
# files without having to all lines from the engine's directory.
class StaticPermission < ActiveRecord::Base
  include ActiveRbacMixins::StaticPermissionMixins::Core
  include ActiveRbacMixins::StaticPermissionMixins::Validation
end
