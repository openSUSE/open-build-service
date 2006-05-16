# Users wrap the users records in the database and represent users in the
# ActiveRbac model.
#
# Passwords are hashed when the object is written to the database the first 
# time. After this, only the hashed password is available. You can check
# whether the record already is in the dabase using 
# ActiveRecord::Base.new_record?
#
# The User ActiveRecord class mixes in the "ActiveRbacMixins::UserMixin" module.
# This module contains the actual implementation. It is kept there so
# you can easily provide your own model files without having to all lines
# from the engine's directory
class User < ActiveRecord::Base
  include ActiveRbacMixins::UserMixin
end
