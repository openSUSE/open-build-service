require 'kconv'
require_dependency 'api_exception'

class User < ActiveRecord::Base
  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :watched_projects, :foreign_key => 'bs_user_id', :dependent => :destroy
  has_many :groups_users, :foreign_key => 'user_id'
  has_many :roles_users, :foreign_key => 'user_id'
  has_many :relationships

  has_many :status_messages
  has_many :messages

  @@ldap_search_con = nil
  
  # users have a n:m relation to group
  has_and_belongs_to_many :groups, -> { uniq() }
  # users have a n:m relation to roles
  has_and_belongs_to_many :roles, -> { uniq() }
  # users have 0..1 user_registration records assigned to them
  has_one :user_registration

  # This method returns an array with the names of all available
  # password hash types supported by this User class.
  def self.password_hash_types
    default_password_hash_types
  end

  # When a record object is initialized, we set the state, password
  # hash type, indicator whether the password has freshly been set 
  # (@new_password) and the login failure count to 
  # unconfirmed/false/0 when it has not been set yet.
  before_validation(:on => :create) do

    self.state = User.states['unconfirmed'] if self.state.nil? 
    self.password_hash_type = 'md5' if self.password_hash_type.to_s == ''

    @new_password = false if @new_password.nil?
    @new_hash_type = false if @new_hash_type.nil?

    self.login_failure_count = 0 if self.login_failure_count.nil?
  end

  # Set the last login time etc. when the record is created at first.
  def before_create
    self.last_logged_in_at = Time.now
  end

  # Override the accessor for the "password_hash_type" property so it sets
  # the "@new_hash_type" private property to signal that the password's
  # hash method has been changed. Changing the password hash type is only
  # possible if a new password has been provided.
  def password_hash_type=(value)
    write_attribute(:password_hash_type, value)
    @new_hash_type = true
  end

  # After saving, we want to set the "@new_hash_type" value set to false
  # again.
  after_save '@new_hash_type = false'

  # Add accessors for "new_password" property. This boolean property is set 
  # to true when the password has been set and validation on this password is
  # required.
  attr_accessor :new_password

  # Generate accessors for the password confirmation property.
  attr_accessor :password_confirmation

  # Overriding the default accessor to update @new_password on setting this
  # property.
  def password=(value)
    write_attribute(:password, value)
    @new_password = true
  end
  
  # Returns true if the password has been set after the User has been loaded
  # from the database and false otherwise
  def new_password?
    @new_password == true
  end

  # Method to update the password and confirmation at the same time. Call
  # this method when you update the password from code and don't need 
  # password_confirmation - which should really only be used when data
  # comes from forms. 
  #
  # A ussage example:
  #
  #   user = User.find(1)
  #   user.update_password "n1C3s3cUreP4sSw0rD"
  #   user.save
  #
  def update_password(pass)
    self.password_crypted = hash_string(pass).crypt("os")
    self.password_confirmation = hash_string(pass)
    self.password = hash_string(pass)
  end

  # After saving the object into the database, the password is not new any more.
  after_save '@new_password = false'

  # This method returns all groups assigned to the given user via ldap - including
  # the ones he gets by being assigned through group inheritance.
  def all_groups_ldap(group_ldap)
    result = Array.new
    for group in group_ldap
      result << group.ancestors_and_self
    end

    result.flatten!
    result.uniq!

    return result
  end

  # This method returns true if the user is assigned the role with one of the
  # role titles given as parameters. False otherwise.
  def has_role?(*role_titles)
    obj = all_roles.detect do |role| 
      role_titles.include?(role.title)
    end
    
    return !obj.nil?
  end

  # This method returns a list of all the StaticPermission entities that
  # have been assigned to this user through his roles.
  def all_static_permissions
    permissions = Array.new

    all_roles.each do |role|
      permissions.concat(role.static_permissions)
    end

    return permissions
  end

  # This method creates a new registration token for the current user. Raises 
  # a MultipleRegistrationTokens Exception if the user already has a 
  # registration token assigned to him.
  #
  # Use this method instead of creating user_registration objects directly!
  def create_user_registration
    raise unless user_registration.nil?

    token = UserRegistration.new
    self.user_registration = token
  end

  # This method expects the token for the current user. If the token is
  # correct, the user's state will be set to "confirmed" and the associated
  # "user_registration" record will be removed.
  # Returns "true" on success and "false" on failure/or the user is already
  # confirmed and/or has no "user_registration" record.
  def confirm_registration(token)
    return false if self.user_registration.nil?
    return false if user_registration.token != token
    return false unless state_transition_allowed?(state, User.states['confirmed'])

    self.state = User.states['confirmed']
    self.save!
    user_registration.destroy

    return true
  end

  # Returns the default state of new User objects.
  def self.default_state
    User.states['unconfirmed']
  end

  # Returns true when users with the given state may log in. False otherwise.
  # The given parameter must be an integer.
  def self.state_allows_login?(state)
    [ User.states['confirmed'], User.states['retrieved_password'] ].include?(state)
  end

  # Overwrite the state setting so it backs up the initial state from
  # the database.
  def state=(value)
    @old_state = state if @old_state.nil?
    write_attribute(:state, value)
  end

  # Overriding this method to make "login" visible as "User name". This is called in
  # forms to create error messages.
  def human_attribute_name (attr)
    return case attr
           when 'login' then 'User name'
           else attr.humanize
           end
  end

  # This static method removes all users with state "unconfirmed" and expired
  # registration tokens.
  def self.purge_users_with_expired_registration
    registrations = UserRegistration.find :all,
    :conditions => [ 'expires_at < ?', Time.now.ago(2.days) ]
    registrations.each do |registration|
      registration.user.destroy
    end
  end

  # This static method tries to find a user with the given login and password
  # in the database. Returns the user or nil if he could not be found
  def self.find_with_credentials(login, password)
    # Find user
    user = User.where(login: login).first

    # If the user could be found and the passwords equal then return the user
    if not user.nil? and user.password_equals? password
      if user.login_failure_count > 0
        user.login_failure_count = 0
        self.execute_without_timestamps { user.save! }
      end

      return user
    end

    # Otherwise increase the login count - if the user could be found - and return nil
    if not user.nil?
      user.login_failure_count = user.login_failure_count + 1
      self.execute_without_timestamps { user.save! }
    end

    return nil
  end

  # This static method tries to update the entry with the given info in the 
  # active directory server.  Return the error msg if any error occurred
  def self.update_entry_ldap(login, newlogin, newemail, newpassword)
    logger.debug( " Modifying #{login} to #{newlogin} #{newemail} using ldap" )
    
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return "Unable to connect to LDAP server"
    end
    user_filter = "(#{LCONFIG['dap_search_attr']}=#{login})"
    dn = String.new
    ldap_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
      dn = entry.dn
    end
    if dn.empty?
      logger.debug( "User not found in ldap" )
      return "User not found in ldap"
    end

    # Update mail/password info
    entry = [
             LDAP.mod(LDAP::LDAP_MOD_REPLACE,CONFIG['ldap_mail_attr'],[newemail]),
            ]
    if newpassword
      case CONFIG['ldap_auth_mech']
      when :cleartext then
        entry << LDAP.mod(LDAP::LDAP_MOD_REPLACE,CONFIG['ldap_auth_attr'],[newpassword])
      when :md5 then
        require 'digest/md5'
        require 'base64'
        entry << LDAP.mod(LDAP::LDAP_MOD_REPLACE,CONFIG['ldap_auth_attr'],["{MD5}"+Base64.b64encode(Digest::MD5.digest(newpassword)).chomp])
      end
    end
    begin
      ldap_con.modify(dn, entry)
    rescue LDAP::ResultError
      logger.debug("Error #{ldap_con.err} for #{login} mail/password changing")
      return "Failed to update entry for #{login}: error #{ldap_con.err}"
    end

    # Update the dn name if it is changed
    if not login == newlogin
      begin
        ldap_con.modrdn(dn,"#{CONFIG['ldap_name_attr']}=#{newlogin}", true)
      rescue LDAP::ResultError
        logger.debug("Error #{ldap_con.err} for #{login} dn name changing")
        return "Failed to update dn name for #{login}: error #{ldap_con.err}"
      end
    end

    return
  end

  # This static method tries to add the new entry with the given name/password/mail info in the 
  # active directory server.  Return the error msg if any error occurred
  def self.new_entry_ldap(login, password, mail)
    require 'ldap'
    logger.debug( "Add new entry for #{login} using ldap" )
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return "Unable to connect to LDAP server"
    end
    case CONFIG['ldap_auth_mech']
    when :cleartext then
      ldap_password = password
    when :md5 then
      require 'digest/md5'
      require 'base64'
      ldap_password = "{MD5}"+Base64.b64encode(Digest::MD5.digest(password)).chomp
    end
    entry = [
             LDAP.mod(LDAP::LDAP_MOD_ADD,'objectclass',CONFIG['ldap_object_class']),
             LDAP.mod(LDAP::LDAP_MOD_ADD,CONFIG['ldap_name_attr'],[login]),
             LDAP.mod(LDAP::LDAP_MOD_ADD,CONFIG['ldap_auth_attr'],[ldap_password]),
             LDAP.mod(LDAP::LDAP_MOD_ADD,CONFIG['ldap_mail_attr'],[mail]),       
            ]
    # Added required sn attr
    if defined?( CONFIG['ldap_sn_attr_required'] ) && CONFIG['ldap_sn_attr_required'] == :on
      entry << LDAP.mod(LDAP::LDAP_MOD_ADD,'sn',[login])
    end

    begin
      ldap_con.add("#{CONFIG['ldap_name_attr']}=#{login},#{CONFIG['ldap_entry_base']}", entry)
    rescue LDAP::ResultError
      logger.debug("Error #{ldap_con.err} for #{login}")
      return "Failed to add a new entry for #{login}: error #{ldap_con.err}"
    end
    return
  end

  # This static method tries to delete the entry with the given login in the 
  # active directory server.  Return the error msg if any error occurred
  def self.delete_entry_ldap(login)
    logger.debug( "Deleting #{login} using ldap" )
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return "Unable to connect to LDAP server"
    end
    user_filter = "(#{LCONFIG['dap_search_attr']}=#{login})"
    dn = String.new
    ldap_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
      dn = entry.dn
    end
    if dn.empty?
      logger.debug( "User not found in ldap" )
      return "User not found in ldap"
    end
    begin
      ldap_con.delete(dn)
    rescue LDAP::ResultError
      logger.debug( "Failed to delete: error #{ldap_con.err} for #{login}" )
      return "Failed to delete the entry #{login}: error #{ldap_con.err}"
    end
    return
  end

  # Check if ldap group support is enabled?
  def self.ldapgroup_enabled?
    return CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
  end

  # This static method tries to find a group with the given gorup_title to check whether the group is in the LDAP server.
  def self.find_group_with_ldap(group)
    if defined?( CONFIG['ldap_group_objectclass_attr'] )
      filter = "(&(#{CONFIG['ldap_group_title_attr']}=#{group})(objectclass=#{CONFIG['ldap_group_objectclass_attr']}))"
    else
      filter = "(#{CONFIG['ldap_group_title_attr']}=#{group})"
    end
    result = search_ldap(CONFIG['ldap_group_search_base'], filter)
    if result.nil? 
      logger.debug( "Fail to find group: #{group} in LDAP" )
      return false
    else
      logger.debug( "group dn: #{result[0]}" )
      return true
    end
  end

  # This static method performs the search with the given search_base, filter
  def self.search_ldap(search_base, filter, required_attr = nil)
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return nil
    end
    logger.debug( "Search: #{filter}" )
    result = Array.new
    ldap_con.search( search_base, LDAP::LDAP_SCOPE_SUBTREE, filter ) do |entry|
      result << entry.dn
      result << entry.attrs
      if required_attr and entry.attrs.include?(required_attr)
        result << entry.vals(required_attr)
      end
    end
    if result.empty?
      return nil
    else
      return result
    end
  end
  
  # This static method performs the search with the given grouplist, user to return the groups that the user in 
  def self.render_grouplist_ldap(grouplist, user = nil)
    result = Array.new
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return result
    end

    if not user.nil?
      # search user
      if defined?( CONFIG['ldap_user_filter'] )
        filter = "(&(#{LCONFIG['dap_search_attr']}=#{user})#{CONFIG['ldap_user_filter']})"
      else
        filter = "(#{LCONFIG['dap_search_attr']}=#{user})"
      end
      user_dn = String.new
      user_memberof_attr = String.new
      ldap_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter ) do |entry|
        user_dn = entry.dn
        if defined?( CONFIG['ldap_user_memberof_attr'] ) && entry.attrs.include?( CONFIG['ldap_user_memberof_attr'] )
          user_memberof_attr=entry.vals(CONFIG['ldap_user_memberof_attr'])
        end            
      end
      if user_dn.empty?
        logger.debug( "Failed to find #{user} in ldap" )
        return result
      end
      logger.debug( "User dn: #{user_dn} user_memberof_attr: #{user_memberof_attr}" )
    end

    group_dn = String.new
    group_member_attr = String.new
    grouplist.each do |eachgroup|
      if eachgroup.kind_of? String
        group = eachgroup
      end
      if eachgroup.kind_of? Group
        group = eachgroup.title
      end

      unless group.kind_of? String
        raise ArgumentError, "illegal parameter type to user#render_grouplist_ldap?: #{eachgroup.class.name}"
      end

      # search group
      if defined?( CONFIG['ldap_group_objectclass_attr'] )
        filter = "(&(#{CONFIG['ldap_group_title_attr']}=#{group})(objectclass=#{CONFIG['ldap_group_objectclass_attr']}))" 
      else
        filter = "(#{CONFIG['ldap_group_title_attr']}=#{group})"
      end
      
      # clean group_dn, group_member_attr
      group_dn = ""
      group_member_attr = ""
      logger.debug( "Search group: #{filter}" )         
      ldap_con.search( CONFIG['ldap_group_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter ) do |entry|
        group_dn = entry.dn
        if defined?( CONFIG['ldap_group_member_attr'] ) && entry.attrs.include?(CONFIG['ldap_group_member_attr'])
          group_member_attr = entry.vals(CONFIG['ldap_group_member_attr'])
        end
      end
      if group_dn.empty?
        logger.debug( "Failed to find #{group} in ldap" )
        next
      end
      
      if user.nil?
        result << eachgroup
        next
      end

      # user memberof attr exist?
      if user_memberof_attr and user_memberof_attr.include?(group_dn)
        result << eachgroup
        logger.debug( "#{user} is in #{group}" )
        next
      end
      # group member attr exist?
      if group_member_attr and group_member_attr.include?(user_dn)
        result << eachgroup
        logger.debug( "#{user} is in #{group}" )
        next
      end
      logger.debug("#{user} is not in #{group}")
    end

    return result
  end

  # This static method tries to update the password with the given login in the 
  # active directory server.  Return the error msg if any error occurred
  def self.change_password_ldap(login, password)
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      logger.debug( "Unable to connect to LDAP server" )
      return "Unable to connect to LDAP server"
    end
    user_filter = "(#{LCONFIG['dap_search_attr']}=#{login})"
    dn = String.new
    ldap_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
      dn = entry.dn
    end
    if dn.empty?
      logger.debug( "User not found in ldap" )
      return "User not found in ldap"
    end

    case CONFIG['ldap_auth_mech']
    when :cleartext then
      ldap_password = password
    when :md5 then
      require 'digest/md5'
      require 'base64'
      ldap_password = "{MD5}"+Base64.b64encode(Digest::MD5.digest(password)).chomp
    end
    entry = [
             LDAP.mod(LDAP::LDAP_MOD_REPLACE, CONFIG['ldap_auth_attr'], [ldap_password]),
            ]
    begin
      ldap_con.modify(dn, entry)
    rescue LDAP::ResultError
      logger.debug("Error #{ldap_con.err} for #{login}")
      return "#{ldap_con.err}"
    end

    return
  end


  # This static method tries to find a user with the given login and
  # password in the active directory server.  Returns nil unless 
  # credentials are correctly found using LDAP.
  def self.find_with_ldap(login, password)
    logger.debug( "Looking for #{login} using ldap" )
    ldap_info = Array.new
    # use cache to check the password firstly
    key="ldap_cache_userpasswd:" + login
    require 'digest/md5'
    if Rails.cache.exist?(key)
      ar = Rails.cache.read(key)
      if ar[0] == Digest::MD5.digest(password)
        ldap_info[0] = ar[1]
        ldap_info[1] = ar[2]
        logger.debug("login success for checking with ldap cache")
        return ldap_info
      end 
    end

    # When the server closes the connection, @@ldap_search_con.nil? doesn't catch it
    # @@ldap_search_con.bound? doesn't catch it as well. So when an error occurs, we
    # simply it try it a seccond time, which forces the ldap connection to
    # reinitialize (@@ldap_search_con is unbound and nil).
    ldap_first_try = true
    dn = String.new
    ldap_password = String.new
    user_filter = String.new
    1.times do
      if @@ldap_search_con.nil?
        @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
      end
      ldap_con = @@ldap_search_con
      if ldap_con.nil?
        logger.debug( "Unable to connect to LDAP server" )
        return nil
      end

      if defined?( CONFIG['ldap_user_filter'] )
        user_filter = "(&(#{CONFIG['ldap_search_attr']}=#{login})#{CONFIG['ldap_user_filter']})"
      else
        user_filter = "(#{CONFIG['ldap_search_attr']}=#{login})"
      end
      logger.debug( "Search for #{user_filter}" )
      begin
        ldap_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
          dn = entry.dn
          ldap_info[0] = String.new(entry[CONFIG['ldap_mail_attr']][0])
          if defined?( CONFIG['ldap_authenticate'] ) && CONFIG['ldap_authenticate'] == :local
            if entry[CONFIG['ldap_auth_attr']] then
              ldap_password = entry[CONFIG['ldap_auth_attr']][0]
              logger.debug( "Get auth_attr:#{ldap_password}" )
            else
              logger.debug( "Failed to get attr:#{CONFIG['ldap_auth_attr']}" )
            end
          end
        end
      rescue
        logger.debug( "Search failed:  error #{ @@ldap_search_con.err}: #{ @@ldap_search_con.err2string(@@ldap_search_con.err)}" )
        @@ldap_search_con.unbind()
        @@ldap_search_con = nil
        if ldap_fist_try
          ldap_first_try = false
          redo
        end
        return nil
      end
    end
    if dn.empty?
      logger.debug( "User not found in ldap" )
      return nil
    end
    # Attempt to authenticate user
    case CONFIG['ldap_authenticate']
    when :local then
      authenticated = false
      case CONFIG['ldap_auth_mech']
      when :cleartext then
        if ldap_password == password then
          authenticated = true
        end
      when :md5 then
        require 'digest/md5'
        require 'base64'
        if ldap_password == "{MD5}"+Base64.b64encode(Digest::MD5.digest(password)) then
          authenticated = true
        end
      end
      if authenticated == true
        ldap_info[0] = String.new(entry[CONFIG['ldap_mail_attr']][0])
        ldap_info[1] = String.new(entry[CONFIG['ldap_name_attr']][0])
      end
    when :ldap then
      # Don't match the passwd locally, try to bind to the ldap server
      user_con= initialize_ldap_con(dn,password)
      if user_con.nil?
        logger.debug( "Unable to connect to LDAP server as #{dn} using credentials supplied" )
      else
        # Redo the search as the user for situations where the anon search may not be able to see attributes
        user_con.search( CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE,  user_filter ) do |entry|
          if entry[CONFIG['ldap_mail_attr']] then 
            ldap_info[0] = String.new(entry[CONFIG['ldap_mail_attr']][0])
          end
          if entry[CONFIG['ldap_name_attr']] then
            ldap_info[1] = String.new(entry[CONFIG['ldap_name_attr']][0])
          else
            ldap_info[1] = login
          end
        end
        user_con.unbind()
      end
    end
    Rails.cache.write(key, [Digest::MD5.digest(password), ldap_info[0], ldap_info[1]], :expires_in => 2.minute)
    logger.debug( "login success for checking with ldap server" )
    ldap_info
  end

  # This method checks whether the given value equals the password when
  # hashed with this user's password hash type. Returns a boolean.
  def password_equals?(value)
    return hash_string(value) == self.password
  end

  # Sets the last login time and saves the object. Note: Must currently be 
  # called explicitely!
  def did_log_in
    self.last_logged_in_at = DateTime.now
    self.class.execute_without_timestamps { save }
  end

  # Returns true if the the state transition from "from" state to "to" state 
  # is valid. Returns false otherwise. +new_state+ must be the integer value 
  # of the state as returned by +User.states['state_name']+.
  #
  # Note that currently no permission checking is included here; It does not 
  # matter what permissions the currently logged in user has, only that the
  # state transition is legal in principle.
  def state_transition_allowed?(from, to)
    from = from.to_i
    to = to.to_i

    return true if from == to # allow keeping state

    return case from
           when User.states['unconfirmed']
             true
           when User.states['confirmed']
             [ User.states['retrieved_password'], User.states['locked'], User.states['deleted'] ].include?(to)
           when User.states['locked']
             [ User.states['confirmed'], User.states['deleted'] ].include?(to)
           when User.states['deleted']
             [ User.states['confirmed'] ].include?(to)
           when User.states['retrieved_password']
             [ User.states['confirmed'], User.states['locked'], User.states['deleted'] ].include?(to)
           when 0
             User.states.value?(to)
           else
             false
           end
  end

  # Model Validation

  validates_presence_of   :login, :email, :password, :password_hash_type, :state,
                          :message => 'must be given'

  validates_uniqueness_of :login, 
                          :message => 'is the name of an already existing user.'

  # Overriding this method to do some more validation: Password equals 
  # password_confirmation, state an password hash type being in the range
  # of allowed values.
  def validate
    # validate state and password has type to be in the valid range of values
    errors.add(:password_hash_type, "must be in the list of hash types.") unless User.password_hash_types.include? password_hash_type
    # check that the state transition is valid
    errors.add(:state, "must be a valid new state from the current state.") unless state_transition_allowed?(@old_state, state)

    # validate the password
    if @new_password and not password.nil?
      errors.add(:password, 'must match the confirmation.') unless password_confirmation == password
    end

    # check that the password hash type has not been set if no new password
    # has been provided
    if @new_hash_type and (!@new_password or password.nil?) then
      errors.add(:password_hash_type, 'cannot be changed unless a new password has been provided.')
    end
  end

  validates_format_of    :login, 
                         :with => %r{\A[\w \$\^\-\.#\*\+&'"]*\z}, 
                         :message => 'must not contain invalid characters.'
  validates_length_of    :login, 
                         :in => 2..100, :allow_nil => true,
                         :too_long => 'must have less than 100 characters.', 
                         :too_short => 'must have more than two characters.'

  # We want a valid email address. Note that the checking done here is very
  # rough. Email adresses are hard to validate now domain names may include
  # language specific characters and user names can be about anything anyway.
  # However, this is not *so* bad since users have to answer on their email
  # to confirm their registration.
  validates_format_of :email, 
                      :with => %r{\A([\w\-\.\#\$%&!?*\'\+=(){}|~]+)@([0-9a-zA-Z\-\.\#\$%&!?*\'=(){}|~]+)+\z},
                      :message => 'must be a valid email address.'

  # We want to validate the format of the password and only allow alphanumeric
  # and some punctiation characters.
  # The format must only be checked if the password has been set and the record
  # has not been stored yet and it has actually been set at all. Make sure you
  # include this condition in your :if parameter to validates_format_of when
  # overriding the password format validation.
  validates_format_of :password,
                      :with => %r{\A[\w\.\- !?(){}|~*]+\z},
                      :message => 'must not contain invalid characters.',
                      :if => Proc.new { |user| user.new_password? and not user.password.nil? }

  # We want the password to have between 6 and 64 characters.
  # The length must only be checked if the password has been set and the record
  # has not been stored yet and it has actually been set at all. Make sure you
  # include this condition in your :if parameter to validates_length_of when
  # overriding the length format validation.
  validates_length_of :password,
                      :within => 6..64,
                      :too_long => 'must have between 6 and 64 characters.',
                      :too_short => 'must have between 6 and 64 characters.',
                     :if => Proc.new { |user| user.new_password? and not user.password.nil? }

   class NotFound < APIException
     setup 404
   end

  class << self
    def current
      Thread.current[:user]
    end
    
    def current=(user)
      Thread.current[:user] = user
    end

    def nobodyID
      return Thread.current[:nobody_id] ||= get_by_login("_nobody_").id
    end

    def get_by_login(login)
      find_by_login(login) or raise NotFound.new("Couldn't find User with login = #{login}")
    end

    def find_by_email(email)
      return where(:email => email).first
    end
  end

  # After validation, the password should be encrypted  
  after_validation(:on => :create) do 
    if errors.empty? and @new_password and !password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9];

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt("os"))
      #  ^^^^^^
      
      # write encrypted password to object property
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      self.password_confirmation = nil
      
      # mark the hash type as "not new" any more
      @new_hash_type = false
    else 
      logger.debug "Error - skipping to create user #{errors.empty?} #{@new_password.inspect} #{password.inspect}"
    end
  end

  def to_axml
    Rails.cache.fetch('meta_user_%d' % id) do
      render_axml
    end
  end

  def render_axml( watchlist = false )
    builder = Nokogiri::XML::Builder.new
 
    logger.debug "----------------- rendering person #{self.login} ------------------------"
    builder.person() do |person|
      person.login( self.login )
      person.email( self.email )
      realname = self.realname
      realname.toutf8
      person.realname( realname )
      # FIXME 2.5: turn the state into an enum
      person.state( User.states.keys[self.state-1] )

      self.roles.global.each do |role|
        person.globalrole( role.title )
      end

      # Show the watchlist only to the user for privacy reasons
      if watchlist
        person.watchlist() do |wl|
          self.watched_projects.each do |wp|
            wl.project( :name => wp.project.name ) if Project.valid_name?(wp.project.name)
          end
        end
      end
    end

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT

  end

  # Returns true if the the state transition from "from" state to "to" state
  # is valid. Returns false otherwise. +new_state+ must be the integer value
  # of the state as returned by +User.states['state_name']+.
  #
  # Note that currently no permission checking is included here; It does not
  # matter what permissions the currently logged in user has, only that the
  # state transition is legal in principle.
  def state_transition_allowed?(from, to)
    from = from.to_i
    to = to.to_i

    return true if from == to # allow keeping state

    return case from
      when User.states['unconfirmed']
        true
      when User.states['confirmed']
        ['retrieved_password','locked','deleted','deleted','ichainrequest'].map{|x| User.states[x]}.include?(to)
      when User.states['locked']
        ['confirmed', 'deleted'].map{|x| User.states[x]}.include?(to)
      when User.states['deleted']
        to == User.states['confirmed']
      when User.states['ichainrequest']
        ['locked', 'confirmed', 'deleted'].map{|x| User.states[x]}.include?(to)
      when 0
        User.states.value?(to)
      else
        false
    end
  end

  STATES = {
    'unconfirmed'        => 1,
    'confirmed'          => 2,
    'locked'             => 3,
    'deleted'            => 4,
    'ichainrequest'      => 5,
    'retrieved_password' => 6,
  }

  def self.states
    STATES
  end

  # updates users email address and real name using data transmitted by authentification proxy
  def update_user_info_from_proxy_env(env)
    proxy_email = env["HTTP_X_EMAIL"]
    if not proxy_email.blank? and self.email != proxy_email
      logger.info "updating email for user #{self.login} from proxy header: old:#{self.email}|new:#{proxy_email}"
      self.email = proxy_email
      self.save
    end
    if not env['HTTP_X_FIRSTNAME'].blank? and not env['HTTP_X_LASTNAME'].blank?
      realname = env['HTTP_X_FIRSTNAME'] + " " + env['HTTP_X_LASTNAME']
      if self.realname != realname
        self.realname = realname
        self.save
      end
    end
  end

  #####################
  # permission checks #
  #####################

  def is_admin?
    if @is_admin.nil? # false is fine
      @is_admin = roles.where(title: "Admin").exists?
    end
    @is_admin
  end

  # used to avoid
  def is_admin=(is_she)
    @is_admin = is_she
  end

  def is_in_group?(group)
    if group.nil?
      return false
    end
    if group.kind_of? String
      group = Group.find_by_title(group)
      return false unless group
    end
    if group.kind_of? Fixnum
      group = Group.find(group)
    end
    unless group.kind_of? Group
      raise ArgumentError, "illegal parameter type to User#is_in_group?: #{group.class}"
    end
    if User.ldapgroup_enabled?
      return user_in_group_ldap?(self.login, group) 
    else 
      return !groups_users.where(group_id: group.id).first.nil?
    end
  end

  # This method returns true if the user is granted the permission with one
  # of the given permission titles.
  def has_global_permission?(perm_string)
    logger.debug "has_global_permission? #{perm_string}"
    self.roles.detect do |role|
      return true if role.static_permissions.where("static_permissions.title = ?", perm_string).first
    end
  end
  
  # project is instance of Project
  def can_modify_project?(project, ignoreLock=nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_modify_project?: #{project.class.name}"
    end
    return false if not ignoreLock and project.is_locked?
    return true if is_admin?
    return true if has_global_permission? "change_project"
    return true if has_local_permission? "change_project", project
    return false
  end

  # package is instance of Package
  def can_modify_package?(package, ignoreLock=nil)
    return false if package.nil? # happens with remote packages easily
    unless package.kind_of? Package
      raise ArgumentError, "illegal parameter type to User#can_modify_package?: #{package.class.name}"
    end
    return false if not ignoreLock and package.is_locked?
    return true if is_admin?
    return true if has_global_permission? "change_package"
    return true if has_local_permission? "change_package", package
    return false
  end

  # project is instance of Project
  def can_create_package_in?(project, ignoreLock=nil)
    unless project.kind_of? Project
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return false if not ignoreLock and project.is_locked?
    return true if is_admin?
    return true if has_global_permission? "create_package"
    return true if has_local_permission? "create_package", project
    return false
  end

  # project_name is name of the project
  def can_create_project?(project_name)
    ## special handling for home projects
    return true if project_name == "home:#{self.login}" and ::Configuration.first.allow_user_to_create_home_project
    return true if /^home:#{self.login}:/.match( project_name ) and ::Configuration.first.allow_user_to_create_home_project

    return true if has_global_permission? "create_project"
    p = Project.find_parent_for(project_name)
    return false if p.nil?
    return true  if is_admin?
    return has_local_permission?( "create_project", p)
  end

  def can_modify_attribute_definition?(object)
    return can_create_attribute_definition?(object)
  end
  def can_create_attribute_definition?(object)
    if object.kind_of? AttribType
      object = object.attrib_namespace
    end
    if not object.kind_of? AttribNamespace
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end

    return true  if is_admin?

    abies = object.attrib_namespace_modifiable_bies.includes([:user, :group])
    abies.each do |mod_rule|
      next if mod_rule.user and mod_rule.user != self
      next if mod_rule.group and not is_in_group? mod_rule.group
      return true
    end

    return false
  end

  def can_create_attribute_in?(object, opts)
    if not object.kind_of? Project and not object.kind_of? Package
      raise ArgumentError, "illegal parameter type to User#can_change?: #{project.class.name}"
    end
    unless opts[:namespace]
      raise ArgumentError, "no namespace given"
    end
    unless opts[:name]
      raise ArgumentError, "no name given"
    end

    # find attribute type definition
    if ( not atype = AttribType.find_by_namespace_and_name(opts[:namespace], opts[:name]) or atype.blank? )
      raise ActiveRecord::RecordNotFound, "unknown attribute type '#{opts[:namespace]}:#{opts[:name]}'"
    end

    return true if is_admin?

    # check modifiable_by rules
    abies = atype.attrib_type_modifiable_bies.includes([:user, :group, :role])
    if abies.length > 0
      abies.each do |mod_rule|
        next if mod_rule.user and mod_rule.user != self
        next if mod_rule.group and not is_in_group? mod_rule.group
        next if mod_rule.role and not has_local_role?(mod_rule.role, object)
        return true
      end
    else
      # no rules set for attribute, just check package maintainer rules
      if object.kind_of? Project
        return can_modify_project?(object)
      else
        return can_modify_package?(object)
      end
    end
    # never reached
    return false
  end

  def can_download_binaries?(package)
    return true if is_admin?
    return true if has_global_permission? "download_binaries"
    return true if has_local_permission?("download_binaries", package)
    return false
  end

  def can_source_access?(package)
    return true if is_admin?
    return true if has_global_permission? "source_access"
    return true if has_local_permission?("source_access", package)
    return false
  end

  def can_access?(parm)
    return true if is_admin?
    return true if has_global_permission? "access"
    return true if has_local_permission?("access", parm)
    return false
  end

  def can_access_downloadbinany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_download_binaries?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  def can_access_downloadsrcany?(parm)
    return true if is_admin?
    if parm.kind_of? Package
      return true if can_source_access?(parm)
    end
    return true if can_access?(parm)
    return false
  end

  def groups_ldap ()
    logger.debug "List the groups #{self.login} is in"
    ldapgroups = Array.new
    # check with LDAP
    if User.ldapgroup_enabled?
      grouplist = Group.all
      begin
        ldapgroups = User.render_grouplist_ldap(grouplist, self.login)
      rescue Exception
        logger.debug "Error occurred in searching user_group in ldap."
      end
    end        
    return ldapgroups
  end

  def user_in_group_ldap?(user, group)
    grouplist = []
    if group.kind_of? String
      grouplist.push Group.find_by_title(group)
    else
      grouplist.push group
    end

    begin      
      return true unless User.render_grouplist_ldap(grouplist, user).empty?
    rescue Exception
      logger.debug "Error occurred in searching user_group in ldap."
    end

    return false
  end
  
  def local_permission_check_with_ldap ( group_relationships )
    group_relationships.each do |r|
      return false if r.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, r.group) 
    end
    logger.debug "Failed with local_permission_check_with_ldap"
    return false
  end

  def local_role_check_with_ldap (role, object)
    logger.debug "Checking role with ldap: object #{object.name}, role #{role.title}"
    rels = object.relationships.groups.where(:role_id => role.id).includes(:group)
    for rel in rels
      return false if rel.group.nil?
      #check whether current user is in this group
      return true if user_in_group_ldap?(self.login, rel.group) 
    end
    logger.debug "Failed with local_role_check_with_ldap"
    return false
  end

  def has_local_role?( role, object )
    case object
    when Package
        logger.debug "running local role package check: user #{self.login}, package #{object.name}, role '#{role.title}'"
        rels = object.relationships.where(:role_id => role.id, :user_id => self.id)
        return true if rels.exists?
        rels = object.relationships.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where(:role_id => role.id)
        return true if rels.exists?

        # check with LDAP
        if User.ldapgroup_enabled?
          return true if local_role_check_with_ldap(role, object)
        end

        return has_local_role?(role, object.project)
    when Project
        logger.debug "running local role project check: user #{self.login}, project #{object.name}, role '#{role.title}'"
        rels = object.relationships.where(:role_id => role.id, :user_id => self.id)
        return true if rels.exists?
        rels = object.relationships.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where(:role_id => role.id)
        return true if rels.exists?

        # check with LDAP
        if User.ldapgroup_enabled?
          return true if local_role_check_with_ldap(role, object)
        end

        return false
    end
    return false
  end

  # local permission check
  # if context is a package, check permissions in package, then if needed continue with project check
  # if context is a project, check it, then if needed go down through all namespaces until hitting the root
  # return false if none of the checks succeed
  def has_local_permission?( perm_string, object )
    roles = Role.ids_with_permission(perm_string)
    return false unless roles
    parent = nil
    case object
    when Package
      logger.debug "running local permission check: user #{self.login}, package #{object.name}, permission '#{perm_string}'"
      #check permission for given package
      parent = object.project
    when Project
      logger.debug "running local permission check: user #{self.login}, project #{object.name}, permission '#{perm_string}'"
      #check permission for given project
      parent = object.find_parent
    when nil
      return has_global_permission?(perm_string)
    else
      return false
    end
    rel = object.relationships.where(:user_id => self.id).where("role_id in (?)", roles)
    return true if rel.exists?
    rel = object.relationships.joins(:groups_users).where(:groups_users => {:user_id => self.id}).where("role_id in (?)", roles)
    return true if rel.exists?

    # check with LDAP
    if User.ldapgroup_enabled?
      groups = object.relationships.groups
      return true if local_permission_check_with_ldap(groups.where("role_id in (?)", roles))
    end
    
    if parent 
      #check permission of parent project
      logger.debug "permission not found, trying parent project '#{parent.name}'"
      return has_local_permission?(perm_string, parent)
    end

    return false
  end

  def involved_projects_ids
    # just for maintainer for now.
    role = Role.rolecache["maintainer"]

    ### all projects where user is maintainer
    projects = self.relationships.projects.where(role_id: role.id).pluck(:project_id)

    # all projects where user is maintainer via a group
    projects += Relationship.projects.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: self.id }).pluck(:project_id) 

    projects.uniq
  end
  
  def involved_projects
    # now filter the projects that are not visible
    return Project.where(id: involved_projects_ids)
  end

  # lists packages maintained by this user and are not in maintained projects
  def involved_packages
    # just for maintainer for now.
    role = Role.rolecache["maintainer"]

    projects = involved_projects_ids
    projects << -1 if projects.empty?

    # all packages where user is maintainer
    packages = self.relationships.where(role_id: role.id).joins(:package).where("packages.db_project_id not in (?)", projects).pluck(:package_id)

    # all packages where user is maintainer via a group
    packages += Relationship.packages.where(role_id: role.id).joins(:groups_users).where(groups_users: { user_id: self.id }).pluck(:package_id)

    return Package.where(id: packages).where("db_project_id not in (?)", projects)
  end

  def forbidden_project_ids
    @f_ids ||= ProjectUserRoleRelationship.forbidden_project_ids_for_user(self)
  end

  def user_relevant_packages_for_status
    role_id = Role.rolecache['maintainer'].id
    # First fetch the project ids
    projects_ids = self.involved_projects_ids
    packages = Package.joins("LEFT OUTER JOIN relationships ON (relationships.package_id = packages.id AND relationships.role_id = #{role_id})")
    # No maintainers
    packages = packages.where([
      "(relationships.user_id = ?) OR "\
      "(relationships.user_id is null AND project_id in (?) )", self.id, projects_ids])
    packages.pluck(:id)
  end

  def request_ids_by_class
    result = {}

    rel = BsRequest.collection(user: login, states: ['declined'], roles: ['creator'])
    result[:declined] = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(user: login, states: ['new'], roles: ['maintainer'])
    result[:new] = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(user: login, roles: ['reviewer'], reviewstates: ['new'], states: ['review'])
    result[:reviews] = rel.pluck("bs_requests.id")

    result
  end

  protected
  # This method allows to execute a block while deactivating timestamp
  # updating.
  def self.execute_without_timestamps
    old_state = ActiveRecord::Base.record_timestamps
    ActiveRecord::Base.record_timestamps = false

    yield

    ActiveRecord::Base.record_timestamps = old_state
  end

  private

  # This method returns an array which contains all valid hash types.
  def self.default_password_hash_types
    [ 'md5' ]
  end

  # Hashes the given parameter by the selected hashing method. It uses the
  # "password_salt" property's value to make the hashing more secure.
  def hash_string(value)
    return case password_hash_type
           when 'md5' then Digest::MD5.hexdigest(value + self.password_salt)
           end
  end 

  # this method returns a ldap object using the provided user name
  # and password
  def self.initialize_ldap_con(user_name, password)
    return nil unless defined?( CONFIG['ldap_servers'] )
    ldap_servers = CONFIG['ldap_servers'].split(":")
    ping = false
    server = nil
    count = 0
    
    max_ldap_attempts = defined?( CONFIG['ldap_max_attempts'] ) ? CONFIG['ldap_max_attempts'] : 10
    
    while !ping and count < max_ldap_attempts
      count += 1
      server = ldap_servers[rand(ldap_servers.length)]
      # Ruby only contains TCP echo ping.  Use system ping for real ICMP ping.
      ping = system("ping -c 1 #{server} >/dev/null 2>/dev/null")
    end
    
    if count == max_ldap_attempts
      logger.debug("Unable to ping to any LDAP server: #{CONFIG['ldap_servers']}")
      return nil
    end

    logger.debug( "Connecting to #{server} as '#{user_name}'" )
    begin
      if defined?( CONFIG['ldap_ssl'] ) && CONFIG['ldap_ssl'] == :on
        port = defined?( CONFIG['ldap_port'] ) ? CONFIG['ldap_port'] : 636
        conn = LDAP::SSLConn.new( server, port)
      else
        port = defined?( CONFIG['ldap_port'] ) ? CONFIG['ldap_port'] : 389
        # Use LDAP StartTLS. By default start_tls is off.
        if defined?( CONFIG['ldap_start_tls'] ) && CONFIG['ldap_start_tls'] == :on
          conn = LDAP::SSLConn.new( server, port, true)
        else
          conn = LDAP::Conn.new( server, port)
        end
      end
      conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      if defined?( CONFIG['ldap_referrals'] ) && CONFIG['ldap_referrals'] == :off
        conn.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_OFF)
      end
      conn.bind(user_name, password)
    rescue LDAP::ResultError
      if not conn.nil?
        conn.unbind()
      end
      logger.debug( "Not bound:  error #{conn.err} for #{user_name}" )
      return nil
    end
    logger.debug( "Bound as #{user_name}" )
    return conn
  end

end
