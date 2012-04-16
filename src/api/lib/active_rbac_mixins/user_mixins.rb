module ActiveRbacMixins
  # The UserMixin module provides the functionality for the User
  # ActiveRecord class. You can use it the following way: Create a file 
  # "model/user.rb" in your "RAILS_ENV/app" directory.
  #
  # Here, create the User class and import the User mixin modules, 
  # e.g.:
  #
  #   class User < ActiveRecord::Base
  #     include ActiveRbacMixins::UserMixins::Core
  #     include ActiveRbacMixins::UserMixins::Validation
  #
  #     # insert your custom code here
  #   end
  #
  # This will create a ActiveRecord class you can then extend to your liking (i.e.
  # just imagine you had written all the stuff that ActiveRbac's User
  # class provides and you can now write some custom lines below it).
module UserMixins
    module Core
      @@ldap_search_con = nil
      # This method is called when the module is included.
      #
      # On inclusion, we do a nifty bit of meta programming and make the
      # including class behave like ActiveRBAC's User class without some
      # of the validation. Extensive validation can be done by including the 
      # Validation class.
      def self.included(base)
        base.class_eval do
          # users have a n:m relation to group
          has_and_belongs_to_many :groups, :uniq => true
          # users have a n:m relation to roles
          has_and_belongs_to_many :roles, :uniq => true
          # users have 0..1 user_registration records assigned to them
          has_one :user_registration

          # We don't want to assign things to roles and groups in bulk assigns.
          #attr_protected :roles, :groups, :created_at, :updated_at, :last_logged_in_at, :login_failure_count, :password_hash_type
          # NOTE: Can't mix attr_protected and attr_accessible, but we set the latter to nil by default since
          # git commit 107d7a612. Thus we have to explicitly list the allowed attributes:
          attr_accessible :login, :email, :realname, :password, :password_confirmation, :state

          # This method returns a hash with the the available user states. 
          # By default it returns the private class constant DEFAULT_STATES.
          def self.states
            default_states
          end

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
            self.password_confirmation = pass
            self.password = pass
          end

          # After saving the object into the database, the password is not new any more.
          after_save '@new_password = false'

          # This method writes the attribute "password" to the hashed version. It is 
          # called in the after_validation hook set by the "after_validation" command
          # above.
          # The password is only encrypted when no errors occurred on validation, the
          # password is new and the password is not nil.
          # This method also sets the "password_salt" property's value used in 
          # User#hash_string.
          # After encryption, the password's "new" state is reset and the confirmation
          # is cleared. The password hash's type will also be set to "not new" since
          # we get problems with double validation (as it happens when using save!)
          # otherwise.
          def encrypt_password
            if errors.count == 0 and @new_password and not password.nil?
              # generate a new 10-char long hash only Base64 encoded so things are compatible
              self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9]; 

              # write encrypted password to object property
              write_attribute(:password, hash_string(password))

              # mark password as "not new" any more
              @new_password = false
              self.password_confirmation = nil
              
              # mark the hash type as "not new" any more
              @new_hash_type = false
            end
          end

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
            user = User.find :first,
                             :conditions => [ 'login = ?', login ]

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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return "Unable to connect to LDAP server"
            end
            user_filter = "(#{LDAP_SEARCH_ATTR}=#{login})"
            dn = String.new
            ldap_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
              dn = entry.dn
            end
            if dn.empty?
              logger.debug( "User not found in ldap" )
              return "User not found in ldap"
            end

            # Update mail/password info
            entry = [
                  LDAP.mod(LDAP::LDAP_MOD_REPLACE,LDAP_MAIL_ATTR,[newemail]),
                  ]
            if newpassword
              case LDAP_AUTH_MECH
              when :cleartext then
                entry << LDAP.mod(LDAP::LDAP_MOD_REPLACE,LDAP_AUTH_ATTR,[newpassword])
              when :md5 then
                require 'digest/md5'
                require 'base64'
                entry << LDAP.mod(LDAP::LDAP_MOD_REPLACE,LDAP_AUTH_ATTR,["{MD5}"+Base64.b64encode(Digest::MD5.digest(newpassword)).chomp])
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
                ldap_con.modrdn(dn,"#{LDAP_NAME_ATTR}=#{newlogin}", true)
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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return "Unable to connect to LDAP server"
            end
            case LDAP_AUTH_MECH
            when :cleartext then
              ldap_password = password
            when :md5 then
              require 'digest/md5'
              require 'base64'
              ldap_password = "{MD5}"+Base64.b64encode(Digest::MD5.digest(password)).chomp
            end
            entry = [
              LDAP.mod(LDAP::LDAP_MOD_ADD,'objectclass',LDAP_OBJECT_CLASS),
              LDAP.mod(LDAP::LDAP_MOD_ADD,LDAP_NAME_ATTR,[login]),
              LDAP.mod(LDAP::LDAP_MOD_ADD,LDAP_AUTH_ATTR,[ldap_password]),
              LDAP.mod(LDAP::LDAP_MOD_ADD,LDAP_MAIL_ATTR,[mail]),       
            ]
            # Added required sn attr
            if defined?( LDAP_SN_ATTR_REQUIRED ) && LDAP_SN_ATTR_REQUIRED == :on
              entry << LDAP.mod(LDAP::LDAP_MOD_ADD,'sn',[login])
            end

            begin
              ldap_con.add("#{LDAP_NAME_ATTR}=#{login},#{LDAP_ENTRY_BASE}", entry)
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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return "Unable to connect to LDAP server"
            end
            user_filter = "(#{LDAP_SEARCH_ATTR}=#{login})"
            dn = String.new
            ldap_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
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
            if defined?( LDAP_GROUP_OBJECTCLASS_ATTR )
              filter = "(&(#{LDAP_GROUP_TITLE_ATTR}=#{group})(objectclass=#{LDAP_GROUP_OBJECTCLASS_ATTR}))"
            else
              filter = "(#{LDAP_GROUP_TITLE_ATTR}=#{group})"
            end
            result = search_ldap(LDAP_GROUP_SEARCH_BASE, filter)
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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return result
            end

            if not user.nil?
              # search user
              if defined?( LDAP_USER_FILTER )
                filter = "(&(#{LDAP_SEARCH_ATTR}=#{user})#{LDAP_USER_FILTER})"
              else
                filter = "(#{LDAP_SEARCH_ATTR}=#{user})"
              end
              user_dn = String.new
              user_memberof_attr = String.new
              ldap_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, filter ) do |entry|
                user_dn = entry.dn
                if defined?( LDAP_USER_MEMBEROF_ATTR ) && entry.attrs.include?( LDAP_USER_MEMBEROF_ATTR )
                  user_memberof_attr=entry.vals(LDAP_USER_MEMBEROF_ATTR)
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
              if defined?( LDAP_GROUP_OBJECTCLASS_ATTR )
                filter = "(&(#{LDAP_GROUP_TITLE_ATTR}=#{group})(objectclass=#{LDAP_GROUP_OBJECTCLASS_ATTR}))" 
              else
                filter = "(#{LDAP_GROUP_TITLE_ATTR}=#{group})"
              end
              
              # clean group_dn, group_member_attr
              group_dn = ""
              group_member_attr = ""
              logger.debug( "Search group: #{filter}" )         
              ldap_con.search( LDAP_GROUP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, filter ) do |entry|
                group_dn = entry.dn
                if defined?( LDAP_GROUP_MEMBER_ATTR ) && entry.attrs.include?(LDAP_GROUP_MEMBER_ATTR)
                  group_member_attr = entry.vals(LDAP_GROUP_MEMBER_ATTR)
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
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return "Unable to connect to LDAP server"
            end
            user_filter = "(#{LDAP_SEARCH_ATTR}=#{login})"
            dn = String.new
            ldap_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
              dn = entry.dn
            end
            if dn.empty?
              logger.debug( "User not found in ldap" )
              return "User not found in ldap"
            end

            case LDAP_AUTH_MECH
            when :cleartext then
              ldap_password = password
            when :md5 then
              require 'digest/md5'
              require 'base64'
              ldap_password = "{MD5}"+Base64.b64encode(Digest::MD5.digest(password)).chomp
            end
            entry = [
              LDAP.mod(LDAP::LDAP_MOD_REPLACE, LDAP_AUTH_ATTR, [ldap_password]),
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
            if defined?( LDAP_OBSDB_FILTER ) && LDAP_OBSDB_FILTER == :on
              logger.debug( "LDAP_OBSDB_FILTER = :on" )
              logger.debug( "Looking for user (#{login}) in obs database before using ldap" )
              db_con = User.find_by_login( login )
              if db_con.nil?
                logger.debug( "User (#{login}) not found in obs database" )
                return nil
              else
                logger.debug( "User (#{login}) found in obs database" )
              end
            end

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

            if @@ldap_search_con.nil?
              @@ldap_search_con = initialize_ldap_con(LDAP_SEARCH_USER, LDAP_SEARCH_AUTH)
            end
            ldap_con = @@ldap_search_con
            if ldap_con.nil?
              logger.debug( "Unable to connect to LDAP server" )
              return nil
            end

            if defined?( LDAP_USER_FILTER )
              user_filter = "(&(#{LDAP_SEARCH_ATTR}=#{login})#{LDAP_USER_FILTER})"
            else
              user_filter = "(#{LDAP_SEARCH_ATTR}=#{login})"
            end
            logger.debug( "Search for #{user_filter}" )
            dn = String.new
            ldap_password = String.new
            begin
              ldap_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE, user_filter ) do |entry|
                dn = entry.dn
                ldap_info[0] = String.new(entry[LDAP_MAIL_ATTR][0])
                if defined?( LDAP_AUTHENTICATE ) && LDAP_AUTHENTICATE == :local
                  if entry[LDAP_AUTH_ATTR] then
                    ldap_password = entry[LDAP_AUTH_ATTR][0]
                    logger.debug( "Get auth_attr:#{ldap_password}" )
                  else
                    logger.debug( "Failed to get attr:#{LDAP_AUTH_ATTR}" )
                  end
                end
              end
            rescue
              logger.debug( "Search failed:  error #{ @@ldap_search_con.err}" )
              @@ldap_search_con.unbind
              @@ldap_search_con = nil
              return nil
            end
            if dn.empty?
              logger.debug( "User not found in ldap" )
              return nil
            end
            # Attempt to authenticate user
            case LDAP_AUTHENTICATE
            when :local then
              authenticated = false
              case LDAP_AUTH_MECH
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
                ldap_info[0] = String.new(entry[LDAP_MAIL_ATTR][0])
                ldap_info[1] = String.new(entry[LDAP_NAME_ATTR][0])
              end
            when :ldap then
              # Don't match the passwd locally, try to bind to the ldap server
              user_con= initialize_ldap_con(dn,password)
              if user_con.nil?
                logger.debug( "Unable to connect to LDAP server as #{dn} using credentials supplied" )
              else
                # Redo the search as the user for situations where the anon search may not be able to see attributes
                user_con.search( LDAP_SEARCH_BASE, LDAP::LDAP_SCOPE_SUBTREE,  user_filter ) do |entry|
                  if entry[LDAP_MAIL_ATTR] then 
                    ldap_info[0] = String.new(entry[LDAP_MAIL_ATTR][0])
                  end
                  if entry[LDAP_NAME_ATTR] then
                    ldap_info[1] = String.new(entry[LDAP_NAME_ATTR][0])
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

          # After validation, the password should be encrypted  
          after_validation :encrypt_password

          protected
            # This method allows to execute a block while deactivating timestamp
            # updating.
            def self.execute_without_timestamps
              old_state = ActiveRecord::Base.record_timestamps
              ActiveRecord::Base.record_timestamps = false

              yield

              ActiveRecord::Base.record_timestamps = old_state
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

          private
            # This method returns a hash which contains a mapping of user states 
            # valid by default and their description.
            def self.default_states
              {
                'unconfirmed' => 1,
                'confirmed' => 2,
                'locked' => 3,
                'deleted' => 4,
                # The user has just retrieved his password and he must now
                # it. The user cannot anything in this state but change his
                # password after having logged in and retrieve another one.
                'retrieved_password' => 5
              }
            end

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
              return nil unless defined?( LDAP_SERVERS )
              ldap_servers = LDAP_SERVERS.split(":")
              ping = false
              server = nil
              count = 0
              
              max_ldap_attempts = defined?( LDAP_MAX_ATTEMPTS ) ? LDAP_MAX_ATTEMPTS : 10
              
              while !ping and count < max_ldap_attempts
                count += 1
                server = ldap_servers[rand(ldap_servers.length)]
                # Ruby only contains TCP echo ping.  Use system ping for real ICMP ping.
                ping = system("ping -c 1 #{server} >/dev/null 2>/dev/null")
              end
              
              if count == max_ldap_attempts
                logger.debug("Unable to ping to any LDAP server: #{LDAP_SERVERS}")
                return nil
              end

              logger.debug( "Connecting to #{server} as '#{user_name}'" )
              begin
                if defined?( LDAP_SSL ) && LDAP_SSL == :on
                  port = defined?( LDAP_PORT ) ? LDAP_PORT : 636
                  conn = LDAP::SSLConn.new( server, port)
                else
                  port = defined?( LDAP_PORT ) ? LDAP_PORT : 389
                  # Use LDAP StartTLS. By default start_tls is off.
		  if defined?( LDAP_START_TLS ) && LDAP_START_TLS == :on
                    conn = LDAP::SSLConn.new( server, port, true)
                  else
                    conn = LDAP::Conn.new( server, port)
		  end
                end
                conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
                if defined?( LDAP_REFERRALS ) && LDAP_REFERRALS == :off
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
      end
    end

    module Validation
      # This method is called when the module is included.
      #
      # On inclusion, we do a nifty bit of meta programming and make the
      # including class validate as ActiveRBAC's User class does.
      def self.included(base)
        base.class_eval do
          validates_format_of     :login, 
                                  :with => %r{^[\w \$\^\-\.#\*\+&'"]*$}, 
                                  :message => 'must not contain invalid characters.'
          validates_length_of     :login, 
                                  :in => 2..100, :allow_nil => true,
                                  :too_long => 'must have less than 100 characters.', 
                                  :too_short => 'must have more than two characters.'

          # We want a valid email address. Note that the checking done here is very
          # rough. Email adresses are hard to validate now domain names may include
          # language specific characters and user names can be about anything anyway.
          # However, this is not *so* bad since users have to answer on their email
          # to confirm their registration.
          validates_format_of :email, 
                              :with => %r{^([\w\-\.\#\$%&!?*\'\+=(){}|~]+)@([0-9a-zA-Z\-\.\#\$%&!?*\'=(){}|~]+)+$},
                              :message => 'must be a valid email address.'

          # We want to validate the format of the password and only allow alphanumeric
          # and some punctiation characters.
          # The format must only be checked if the password has been set and the record
          # has not been stored yet and it has actually been set at all. Make sure you
          # include this condition in your :if parameter to validates_format_of when
          # overriding the password format validation.
          validates_format_of :password,
                              :with => %r{^[\w\.\- !?(){}|~*]+$},
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
        end
      end
    end
end
end
