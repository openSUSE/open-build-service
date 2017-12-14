# the purpose of this mixin is to get the user functions having to do with ldap into one file
class UserLdapStrategy
  @@ldap_search_con = nil

  def is_in_group?(user, group)
    user_in_group_ldap? user.login, group
  end

  def local_role_check(role, object)
    local_role_check_with_ldap role, object
  end

  def local_permission_check(roles, object)
    groups = object.relationships.groups
    local_permission_check_with_ldap(groups.where('role_id in (?)', roles))
  end

  def groups(user)
    render_grouplist_ldap(Group.all, user.login)
  end

  # This static method tries to find a group with the given gorup_title to check whether the group is in the LDAP server.
  def self.find_group_with_ldap(group)
    result = search_ldap(group)
    if result.nil?
      Rails.logger.info("Fail to find group: #{group} in LDAP")
      return false
    else
      Rails.logger.debug("group dn: #{result[0]}")
      return true
    end
  end

  # This static method performs the search with the given search_base, filter
  def self.search_ldap(group)
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    if @@ldap_search_con.nil?
      Rails.logger.info('Unable to connect to LDAP server')
      return
    end
    filter = ldap_group_filter(group)
    Rails.logger.debug("Search: #{filter}")
    result = []
    @@ldap_search_con.search(CONFIG['ldap_group_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
      result << entry.dn
      result << entry.attrs
    end

    return if result.empty?
    result
  end
  private_class_method :search_ldap

  def self.ldap_group_filter(group)
    if CONFIG.has_key?('ldap_group_objectclass_attr')
      "(&(#{CONFIG['ldap_group_title_attr']}=#{group})(objectclass=#{CONFIG['ldap_group_objectclass_attr']}))"
    else
      "(#{CONFIG['ldap_group_title_attr']}=#{group})"
    end
  end
  private_class_method :ldap_group_filter

  # This static method performs the search with the given grouplist, user to return the groups that the user in
  def self.render_grouplist_ldap(grouplist, user = nil)
    result = Array.new
    if @@ldap_search_con.nil?
      @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
    end
    ldap_con = @@ldap_search_con
    if ldap_con.nil?
      Rails.logger.info('Unable to connect to LDAP server')
      return result
    end

    if user
      # search user
      if CONFIG['ldap_user_filter']
        filter = "(&(#{CONFIG['ldap_search_attr']}=#{user})#{CONFIG['ldap_user_filter']})"
      else
        filter = "(#{CONFIG['ldap_search_attr']}=#{user})"
      end
      user_dn = String.new
      user_memberof_attr = String.new
      ldap_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
        user_dn = entry.dn
        if CONFIG['ldap_user_memberof_attr'].in?(entry.attrs)
          user_memberof_attr = entry.vals(CONFIG['ldap_user_memberof_attr'])
        end
      end
      if user_dn.empty?
        Rails.logger.info("Failed to find #{user} in ldap")
        return result
      end
      Rails.logger.debug("User dn: #{user_dn} user_memberof_attr: #{user_memberof_attr}")
    end

    group_dn = String.new
    group_member_attr = String.new
    grouplist.each do |eachgroup|
      if eachgroup.is_a? String
        group = eachgroup
      end
      if eachgroup.is_a? Group
        group = eachgroup.title
      end

      unless group.is_a? String
        raise ArgumentError, "illegal parameter type to UserLdapStrategy#render_grouplist_ldap?: #{eachgroup.class.name}"
      end

      # clean group_dn, group_member_attr
      group_dn = ''
      group_member_attr = ''
      filter = ldap_group_filter(group)
      Rails.logger.debug("Search group: #{filter}")
      ldap_con.search(CONFIG['ldap_group_search_base'], LDAP::LDAP_SCOPE_SUBTREE, filter) do |entry|
        group_dn = entry.dn
        if CONFIG['ldap_group_member_attr'].in?(entry.attrs)
          group_member_attr = entry.vals(CONFIG['ldap_group_member_attr'])
        end
      end
      if group_dn.empty?
        Rails.logger.info("Failed to find #{group} in ldap")
        next
      end

      if user.nil?
        result << eachgroup
        next
      end

      # user memberof attr exist?
      if user_memberof_attr && user_memberof_attr.include?(group_dn)
        result << eachgroup
        Rails.logger.debug("#{user} is in #{group}")
        next
      end
      # group member attr exist?
      if group_member_attr && group_member_attr.include?(user_dn)
        result << eachgroup
        Rails.logger.debug("#{user} is in #{group}")
        next
      end
      Rails.logger.debug("#{user} is not in #{group}")
    end

    result
  end

  def self.authenticate_with_local(password, entry)
    if !entry.key?(CONFIG['ldap_auth_attr']) || entry[CONFIG['ldap_auth_attr']].empty?
      Rails.logger.info("Failed to get attr:#{CONFIG['ldap_auth_attr']}")
      return false
    end

    ldap_password = entry[CONFIG['ldap_auth_attr']][0]

    case CONFIG['ldap_auth_mech']
    when :cleartext
      ldap_password == password
    when :md5
      ldap_password == '{MD5}' + Base64.encode64(Digest::MD5.digest(password))
    else
      Rails.logger.error("Unknown ldap_auth_mech setting: #{CONFIG['ldap_auth_mech']}")

      false
    end
  end

  # convert distinguished name to user principal name
  # see also: http://technet.microsoft.com/en-us/library/cc977992.aspx
  def self.dn2user_principal_name(dn)
    upn = ''
    # implicitly convert array to string
    dn = [dn].flatten.join(',')
    begin
      dn_components = dn.split(',').map { |n| n.strip.split('=') }
      dn_uid = dn_components.select { |x, _| x == 'uid' }.map { |_, y| y }
      dn_path = dn_components.select { |x, _| x == 'dc' }.map { |_, y| y }
      upn = "#{dn_uid.fetch(0)}@#{dn_path.join('.')}"
    rescue
      # if we run into unexpected input just return an empty string
    end

    upn
  end

  # This static method tries to find a user with the given login and
  # password in the active directory server.  Returns nil unless
  # credentials are correctly found using LDAP.
  def self.find_with_ldap(login, password)
    Rails.logger.debug("Looking for #{login} using ldap")

    # When the server closes the connection, @@ldap_search_con.nil? doesn't catch it
    # @@ldap_search_con.bound? doesn't catch it as well. So when an error occurs, we
    # simply it try it a seccond time, which forces the ldap connection to
    # reinitialize (@@ldap_search_con is unbound and nil).
    ldap_first_try = true
    user = nil
    user_filter = ''

    1.times do
      if @@ldap_search_con.nil?
        @@ldap_search_con = initialize_ldap_con(CONFIG['ldap_search_user'], CONFIG['ldap_search_auth'])
      end
      ldap_con = @@ldap_search_con
      if ldap_con.nil?
        Rails.logger.info('Unable to connect to LDAP server')
        return
      end

      if CONFIG.has_key?('ldap_user_filter')
        user_filter = "(&(#{CONFIG['ldap_search_attr']}=#{login})#{CONFIG['ldap_user_filter']})"
      else
        user_filter = "(#{CONFIG['ldap_search_attr']}=#{login})"
      end
      Rails.logger.debug("Search for #{CONFIG['ldap_search_base']} #{user_filter}")
      begin
        ldap_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter) do |entry|
          user = entry.to_hash
        end
      rescue StandardError
        Rails.logger.info("Search failed:  error #{@@ldap_search_con.err}: #{@@ldap_search_con.err2string(@@ldap_search_con.err)}")
        @@ldap_search_con.unbind
        @@ldap_search_con = nil

        if ldap_first_try
          ldap_first_try = false
          redo
        end

        return
      end
    end

    if user.nil?
      Rails.logger.info('User not found in ldap')
      return
    end
    # Attempt to authenticate user
    case CONFIG['ldap_authenticate']
    when :local then
      unless authenticate_with_local(password, user)
        Rails.logger.info("Unable to local authenticate #{user['dn']}")
        return
      end
    when :ldap then
      # ruby-ldap returns true if password is empty
      # https://github.com/ruby-ldap/ruby-net-ldap/issues/5
      return if password.blank?
      # Don't match the passwd locally, try to bind to the ldap server
      user_con = initialize_ldap_con(user['dn'], password)
      if user_con.nil?
        Rails.logger.info("Unable to connect to LDAP server as #{user['dn']} using credentials supplied")
        return
      else
        # Redo the search as the user for situations where the anon search may not be able to see attributes
        user_con.search(CONFIG['ldap_search_base'], LDAP::LDAP_SCOPE_SUBTREE, user_filter) do |entry|
          user.replace(entry.to_hash)
        end
        user_con.unbind
      end
    else # If no CONFIG['ldap_authenticate'] is given do not return the ldap_info !
      Rails.logger.error("Unknown ldap_authenticate setting: '#{CONFIG['ldap_authenticate']}' " +
                         "so #{user['dn']} not authenticated. Ensure ldap_authenticate uses a valid symbol")
      return
    end

    # Only collect the required user information *AFTER* we successfully
    # completed the authentication!
    ldap_info = []

    if user[CONFIG['ldap_mail_attr']]
      ldap_info[0] = String.new(user[CONFIG['ldap_mail_attr']][0])
    else
      ldap_info[0] = dn2user_principal_name(user['dn'])
    end

    if user[CONFIG['ldap_name_attr']]
      ldap_info[1] = String.new(user[CONFIG['ldap_name_attr']][0])
    else
      ldap_info[1] = login
    end

    Rails.logger.debug('login success for checking with ldap server')
    ldap_info
  end

  def user_in_group_ldap?(user, group)
    group = (group.is_a?(String) ? Group.find_by_title(group) : group)

    begin
      render_grouplist_ldap([group], user).any?
    rescue Exception
      Rails.logger.info 'Error occurred in searching user_group in ldap.'
      false
    end
  end

  def local_permission_check_with_ldap(group_relationships)
    relationship_groups_contains_user?(group_relationships, 'local_permission_check_with_ldap')
  end

  def local_role_check_with_ldap(role, object)
    Rails.logger.debug "Checking role with ldap: object #{object.name}, role #{role.title}"

    relationship_groups_contains_user?(
      object.relationships.groups.where(role_id: role.id).includes(:group), 'local_role_check_with_ldap'
    )
  end

  # this method returns a ldap object using the provided user name
  # and password
  def self.initialize_ldap_con(user_name, password)
    return unless defined?(CONFIG['ldap_servers'])
    require 'ldap'
    ldap_servers = CONFIG['ldap_servers'].split(':')

    # Do 10 attempts to connect to one of the configured LDAP servers. LDAP server
    # to connect to is chosen randomly.
    (CONFIG['ldap_max_attempts'] || 10).times do
      server = ldap_servers[rand(ldap_servers.length)]
      conn = try_ldap_con(server, user_name, password)

      return conn if conn.try(:bound?)
    end

    Rails.logger.error("Unable to bind to any LDAP server: #{CONFIG['ldap_servers']}")
    nil
  end

  def self.ldap_port
    return CONFIG['ldap_port'] if CONFIG['ldap_port']

    CONFIG['ldap_ssl'] == :on ? 636 : 389
  end
  private_class_method :ldap_port

  def self.try_ldap_con(server, user_name, password)
    # implicitly turn array into string
    user_name = [user_name].flatten.join('')

    Rails.logger.debug("Connecting to #{server} as '#{user_name}'")
    port = ldap_port

    begin
      if CONFIG['ldap_ssl'] == :on || CONFIG['ldap_start_tls'] == :on
        conn = LDAP::SSLConn.new(server, port, CONFIG['ldap_start_tls'] == :on)
      else
        conn = LDAP::Conn.new(server, port)
      end
      conn.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
      if CONFIG['ldap_referrals'] == :off
        conn.set_option(LDAP::LDAP_OPT_REFERRALS, LDAP::LDAP_OPT_OFF)
      end
      conn.bind(user_name, password)
    rescue LDAP::ResultError
      conn.unbind if conn.try(:bound?)
      Rails.logger.info("Not bound as #{user_name}: #{conn.err2string(conn.err)}")
      return
    end
    Rails.logger.debug("Bound as #{user_name}")
    conn
  end

  private

  def relationship_groups_contains_user?(relationships, method_name)
    relationships.each do |relationship|
      return false if relationship.group.nil?
      # check whether current user is in this group
      return true if user_in_group_ldap?(login, relationship.group)
    end

    Rails.logger.info "Failed with #{method_name}"

    false
  end
end
