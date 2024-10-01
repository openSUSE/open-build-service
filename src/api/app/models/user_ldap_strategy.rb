# the purpose of this mixin is to get the user functions having to do with ldap into one file
class UserLdapStrategy
  @@ldap_search_con = nil

  class << self
    # This static method tries to find a group with the given group title
    def find_group_with_ldap(group)
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth']) if @@ldap_search_con.nil?
      if @@ldap_search_con.nil?
        Rails.logger.info('UserLdapStrategy: Unable to connect to any of the servers')
        return
      end
      filter = ldap_group_filter(group)
      Rails.logger.debug { "UserLdapStrategy: Search for group '#{filter}'" }
      result = []
      @@ldap_search_con.search(CONFIG['ldap_group_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
        result << entry.dn
        result << entry.attrs
      end

      if result.empty?
        Rails.logger.info("UserLdapStrategy: Fail to find group '#{group}'")
      else
        Rails.logger.debug { "UserLdapStrategy: Found group dn '#{result[0]}'" }
      end

      result
    end

    # This static method tries to find a user with the given login and
    # password in the active directory server.  Returns nil unless
    # credentials are correctly found using LDAP.
    def find_with_ldap(login, password)
      Rails.logger.debug { "UserLdapStrategy: Searching for user '#{login}'" }

      # When the server closes the connection, @@ldap_search_con.nil? doesn't catch it
      # @@ldap_search_con.bound? doesn't catch it as well. So when an error occurs, we
      # simply it try it a seccond time, which forces the ldap connection to
      # reinitialize (@@ldap_search_con is unbound and nil).
      ldap_first_try = true
      user = nil
      user_filter = ''

      # TODO: This should be refactored
      # rubocop:disable Lint/UselessTimes
      1.times do
        @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth']) if @@ldap_search_con.nil?
        ldap_con = @@ldap_search_con
        if ldap_con.nil?
          Rails.logger.info('UserLdapStrategy: Unable to connect to any of the servers')
          return
        end

        user_filter = ldap_user_filter(login)
        Rails.logger.debug { "UserLdapStrategy: Searching '#{CONFIG['ldap_search_base']}' for user with filter '#{user_filter}'" }
        begin
          ldap_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter) do |entry|
            user = entry.to_hash
          end
        rescue StandardError
          Rails.logger.info("UserLdapStrategy: Failed to find user with with filter. Error code '#{@@ldap_search_con.err}' with message '#{@@ldap_search_con.err2string(@@ldap_search_con.err)}'")
          @@ldap_search_con.unbind
          @@ldap_search_con = nil

          if ldap_first_try
            ldap_first_try = false
            redo
          end

          return
        end
      end
      # rubocop:enable Lint/UselessTimes

      if user.nil?
        Rails.logger.info("UserLdapStrategy: Failed to find user '#{login}'")
        return
      end
      # Attempt to authenticate user
      case CONFIG['ldap_authenticate']
      when :local
        unless authenticate_with_local(password, user)
          Rails.logger.info("UserLdapStrategy: Unable to locally authenticate #{user['dn']}")
          return
        end
      when :ldap
        # ruby-ldap returns true if password is empty
        # https://github.com/ruby-ldap/ruby-net-ldap/issues/5
        return if password.blank?

        # Don't match the passwd locally, try to bind to the ldap server
        user_con = initialize_ldap_con(user['dn'], password)
        if user_con.nil?
          Rails.logger.info("UserLdapStrategy: Unable to connect to any of the servers as user '#{user['dn']}'")
          return
        else
          # Redo the search as the user for situations where the anon search may not be able to see attributes
          user_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter) do |entry|
            user.replace(entry.to_hash)
          end
          user_con.unbind
        end
      else # If no CONFIG['ldap_authenticate'] is given do not return the ldap_info !
        Rails.logger.error("UserLdapStrategy: Unknown ldap_authenticate setting: '#{CONFIG['ldap_authenticate']}' " \
                           "so user '#{user['dn']}' could not authenticate. Ensure ldap_authenticate uses a valid symbol (:ldap or :local)")
        return
      end

      # Only collect the required user information *AFTER* we successfully
      # completed the authentication!
      ldap_info = []

      ldap_info[0] = if user[CONFIG['ldap_mail_attr']]
                       String.new(user[CONFIG['ldap_mail_attr']][0])
                     else
                       dn2user_principal_name(user['dn'])
                     end

      ldap_info[1] = if user[CONFIG['ldap_name_attr']]
                       String.new(user[CONFIG['ldap_name_attr']][0])
                     else
                       login
                     end

      Rails.logger.debug { "UserLdapStrategy: Successfully authenticated as user '#{user['dn']}'" }
      ldap_info
    end

    def find_with_credentials(login, password)
      user = User.find_by_login(login)
      return user.authenticate_via_password(password) if user.try(:ignore_auth_services?)

      ldap_info = find_with_ldap(login, password)
      return unless ldap_info

      if user
        Rails.logger.debug { "UserLdapStrategy: Found user '#{login}' in database" }
        user.assign_attributes(email: ldap_info[0], realname: ldap_info[1])
        user.save
      else
        Rails.logger.debug { "UserLdapStrategy: Failed to find user '#{login}' in database, creating" }
        email, name = ldap_info
        user = User.create_user_with_fake_pw!(login: login, email: email, realname: name, state: User.default_user_state, adminnote: 'User created via LDAP')
      end

      user.mark_login!
      user
    end

    private

    # this method returns a ldap object using the provided user name
    # and password
    def initialize_ldap_con(user_name, password)
      return unless defined?(CONFIG['ldap_servers'])

      require 'ldap'
      ldap_servers = CONFIG['ldap_servers'].split(':')

      # Do 10 attempts to connect to one of the configured LDAP servers. LDAP server
      # to connect to is chosen randomly.
      # (CONFIG['ldap_max_attempts'] || 10).times do
      server = ldap_servers[rand(ldap_servers.length)]
      con = try_ldap_con(server, user_name, password)

      return con if con.try(:bound?)

      # end

      Rails.logger.error("UserLdapStrategy:: Unable to bind to any of the servers '#{CONFIG['ldap_servers']}'")
      nil
    end

    def try_ldap_con(server, user_name, password)
      # implicitly turn array into string
      user_name = [user_name].flatten.join

      # LDAP bind quietly dies when user_name or password is nil
      # password can be nil in case of passwordless authentication or anonymous bind
      password ||= ''

      Rails.logger.debug { "UserLdapStrategy: Connecting to server '#{server}' as user '#{user_name}'" }
      port = ldap_port

      begin
        con = if CONFIG['ldap_ssl'] == :on || CONFIG['ldap_start_tls'] == :on
                LDAP::SSLConn.new(server, port, CONFIG['ldap_start_tls'] == :on)
              else
                LDAP::Conn.new(server, port)
              end
        con.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
        con.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_OFF) if CONFIG['ldap_referrals'] == :off
        # con.set_option(LDAP::LDAP_OPT_X_TLS_REQUIRE_CERT, LDAP::LDAP_OPT_X_TLS_ALLOW) if Rails.env.test_ldap? && (CONFIG['ldap_ssl'] == :on || CONFIG['ldap_start_tls'] == :on)
        con.bind(user_name, password)
      rescue LDAP::ResultError => e
        Rails.logger.info("UserLdapStrategy: Failed to bind as user '#{user_name}': #{con.nil? ? e.message : con.err2string(con.err)}")
        con.unbind if con.try(:bound?)
        return
      end
      Rails.logger.debug { "UserLdapStrategy: Bound as '#{user_name}'" }
      con
    end

    # convert distinguished name to user principal name
    # see also: http://technet.microsoft.com/en-us/library/cc977992.aspx
    def dn2user_principal_name(dn)
      upn = ''
      # implicitly convert array to string
      dn = [dn].flatten.join(',')
      begin
        dn_components = dn.split(',').map { |n| n.strip.split('=') }
        dn_uid = dn_components.select { |x, _| x == 'uid' }.map! { |_, y| y }
        dn_path = dn_components.select { |x, _| x == 'dc' }.map! { |_, y| y }
        upn = "#{dn_uid.fetch(0)}@#{dn_path.join('.')}"
      rescue StandardError
        # if we run into unexpected input just return an empty string
      end

      upn
    end

    def authenticate_with_local(password, entry)
      if !entry.key?(CONFIG['ldap_auth_attr']) || entry[CONFIG['ldap_auth_attr']].empty?
        Rails.logger.info("UserLdapStrategy: Failed to get attr '#{CONFIG['ldap_auth_attr']}'")
        return false
      end

      ldap_password = entry[CONFIG['ldap_auth_attr']][0]

      case CONFIG['ldap_auth_mech']
      when :cleartext
        ldap_password == password
      when :md5
        ldap_password == "{MD5}#{Base64.encode64(Digest::MD5.digest(password))}"
      else
        Rails.logger.error("UserLdapStrategy: Unknown ldap_auth_mech setting '#{CONFIG['ldap_auth_mech']}'")

        false
      end
    end

    # This static method performs the search with the given grouplist, user to return the groups that the user in
    def render_grouplist_ldap(grouplist, user = nil)
      result = []
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth']) if @@ldap_search_con.nil?
      ldap_con = @@ldap_search_con
      if ldap_con.nil?
        Rails.logger.info('UserLdapStrategy: Unable to connect to any of the servers')
        return result
      end

      if user
        # search user
        filter = ldap_user_filter(user)

        user_dn = ''
        user_memberof_attr = ''
        ldap_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
          user_dn = entry.dn
          user_memberof_attr = entry.vals(CONFIG['ldap_user_memberof_attr']) if CONFIG['ldap_user_memberof_attr'].in?(entry.attrs)
        end
        if user_dn.empty?
          Rails.logger.info("UserLdapStrategy: Failed to find user '#{user}'")
          return result
        end
        Rails.logger.debug { "UserLdapStrategy: Found user dn '#{user_dn}' with user_memberof_attr '#{user_memberof_attr}'" }
      end

      group_dn = ''
      group_member_attr = ''
      grouplist.each do |eachgroup|
        group = eachgroup if eachgroup.is_a?(String)
        group = eachgroup.title if eachgroup.is_a?(Group)

        raise ArgumentError, "illegal parameter type to UserLdapStrategy#render_grouplist_ldap?: #{eachgroup.class.name}" unless group.is_a?(String)

        # clean group_dn, group_member_attr
        group_dn = ''
        group_member_attr = ''
        filter = ldap_group_filter(group)
        Rails.logger.debug { "UserLdapStrategy: Searching for group '#{filter}'" }
        ldap_con.search(CONFIG['ldap_group_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
          group_dn = entry.dn
          group_member_attr = entry.vals(CONFIG['ldap_group_member_attr']) if CONFIG['ldap_group_member_attr'].in?(entry.attrs)
        end
        if group_dn.empty?
          Rails.logger.info("UserLdapStrategy: Failed to find group '#{group}'")
          next
        end

        if user.nil?
          result << eachgroup
          next
        end

        # user memberof attr exist?
        if user_memberof_attr && user_memberof_attr.include?(group_dn)
          result << eachgroup
          Rails.logger.debug { "UserLdapStrategy: User '#{user}' is in group '#{group}'" }
          next
        end
        # group member attr exist?
        if group_member_attr && group_member_attr.include?(user_dn)
          result << eachgroup
          Rails.logger.debug { "UserLdapStrategy: User '#{user}' is in group '#{group}'" }
          next
        end
        Rails.logger.debug { "UserLdapStrategy: User '#{user}' is not in group '#{group}'" }
      end

      result
    end

    def ldap_group_filter(group)
      if CONFIG.key?('ldap_group_objectclass_attr')
        "(&(#{CONFIG['ldap_group_title_attr']}=#{group})(objectclass=#{CONFIG['ldap_group_objectclass_attr']}))"
      else
        "(#{CONFIG['ldap_group_title_attr']}=#{group})"
      end
    end

    def ldap_user_filter(login)
      if CONFIG.key?('ldap_user_filter')
        "(&(#{CONFIG['ldap_search_attr']}=#{login})#{CONFIG['ldap_user_filter']})"
      else
        "(#{CONFIG['ldap_search_attr']}=#{login})"
      end
    end

    def ldap_port
      return CONFIG['ldap_port'] if CONFIG['ldap_port']

      CONFIG['ldap_ssl'] == :on || CONFIG['ldap_start_tls'] == :on ? 636 : 389
    end
  end

  def is_in_group?(user, group)
    group = (group.is_a?(String) ? Group.find_by_title(group) : group)

    begin
      render_grouplist_ldap([group], user.login).any?
    rescue Exception => e
      Rails.logger.info("UserLdapStrategy: Failed to find user_group '#{group}': #{e.message}")
      false
    end
  end

  def local_role_check(role, object)
    local_role_check_with_ldap(role, object)
  end

  def local_permission_check(roles, object)
    groups = object.relationships.groups
    local_permission_check_with_ldap(groups.where(role_id: roles))
  end

  def list_groups(user)
    render_grouplist_ldap(Group.all, user.login)
  end

  private

  def local_role_check_with_ldap(role, object)
    Rails.logger.debug { "UserLdapStrategy: Checking role for object '#{object.name}' and role '#{role.title}'" }

    relationship_groups_contains_user?(
      object.relationships.groups.where(role_id: role.id).includes(:group), 'local_role_check_with_ldap'
    )
  end

  def local_permission_check_with_ldap(group_relationships)
    relationship_groups_contains_user?(group_relationships, 'local_permission_check_with_ldap')
  end

  def relationship_groups_contains_user?(relationships, method_name)
    relationships.each do |relationship|
      return false if relationship.group.nil?
      # check whether current user is in this group
      # FIXME: What is "login" supposed to be? User.session?
      return true if is_in_group?(login, relationship.group)
    end

    Rails.logger.info("UserLdapStrategy: Failed to check roles with method '#{method_name}'")

    false
  end
end
