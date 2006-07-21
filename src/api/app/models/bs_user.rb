class BsUser < User 
  has_many :watched_projects
  has_many :project_user_role_relationships

  def encrypt_password
    if errors.count == 0 and @new_password and not password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9];

      # write encrypted password to object property

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt("os"))
      #  ^^^^^^
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      password_confirmation = nil
    else 
      logger.debug "Error - skipping to create user"
    end
  end

  def self.states
    states = default_states
    states['ichainrequest'] = 5
  end

end

