# UserRegistration objects represent user_registration records in the database.
# They hold a registration confirmation token, an expiry time and are 
# associated with users.
#
# Developers must not create them manually, but use 
# User.create_user_registration!
#
# The UserRegistration ActiveRecord class mixes in the 
# "ActiveRbacMixins::UserRegistrationMixin" module. This module contains the actual 
# implementation. It is kept there so you can easily provide your own model 
# files without having to all lines from the engine's directory.
class UserRegistration < ActiveRecord::Base
  include ActiveRbacMixins::UserRegistrationMixins::Core
end
