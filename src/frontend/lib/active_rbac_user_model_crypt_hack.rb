require 'user'

# patch User model from active rbac
# We need this to make the user model write the crypted version of the password
# into the database that is queried by the generatepasswords script for the 
# lighttpd server.
# Note: Important is the "require user" at the top because only classes that
# were already loaded can be patched.

class User < ActiveRecord::Base
  def encrypt_password
    if errors.count == 0 and @new_password and not password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9];

      # write encrypted password to object property

      # vvvvvv added this to maintain the password list for lighttpd
      logger.debug "writing le crypt password"
      write_attribute(:password_crypted, password.crypt("os"))
      #  ^^^^^^
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      password_confirmation = nil
    end
  end
end

