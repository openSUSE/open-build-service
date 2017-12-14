# a model that has relationships - e.g. a project and a package
module HasRelationships
  class SaveError < APIException
  end

  def add_user(user, role, ignore_lock = nil)
    Relationship.add_user(self, user, role, ignore_lock)
  end

  def add_group(group, role, ignore_lock = nil)
    Relationship.add_group(self, group, role, ignore_lock)
  end

  # webui code is a huge table - TODO to optimize
  def users
    relationships.users.includes(:user).map(&:user).uniq
  end

  def groups
    relationships.groups.includes(:group).map(&:group).uniq
  end

  def bugowner_emails
    ret = []
    relationships.where(role: Role.hashed['bugowner']).joins(:user).each do |bugowner|
      mail = bugowner.user.email
      ret.push(mail.to_s) if mail
    end
    ret
  end

  def render_relationships(xml)
    relationships.with_users_and_roles.each do |user, role|
      xml.person(userid: user, role: role)
    end

    relationships.with_groups_and_roles.each do |group, role|
      xml.group(groupid: group, role: role)
    end
  end

  def user_has_role?(user, role)
    return true if relationships.where(role_id: role.id, user_id: user.id).exists?
    relationships.where(role_id: role).joins(:groups_users).where(groups_users: { user_id: user.id }).exists?
  end

  def group_has_role?(group, role)
    relationships.where(role_id: role.id, group_id: group.id).exists?
  end

  def remove_role(what, role)
    check_write_access!

    if what.kind_of? Group
      rel = relationships.where(group_id: what.id)
    else
      rel = relationships.where(user_id: what.id)
    end
    rel = rel.where(role_id: role.id) if role
    transaction do
      rel.delete_all
      write_to_backend
    end
  end

  def add_role(what, role)
    check_write_access!

    transaction do
      if what.kind_of? Group
        relationships.create!(role: role, group: what)
      else
        relationships.create!(role: role, user: what)
      end
      write_to_backend
    end
  end

  def maintainers
    direct_users = relationships.with_users_and_roles_query.maintainers.pluck('users.login as login').map { |user| User.find_by_login!(user) }
    users_in_groups = relationships.with_groups_and_roles_query.maintainers.pluck('groups.title as title'). \
      map { |title| Group.find_by_title!(title).users }.flatten
    (direct_users + users_in_groups).uniq
  end

  def remove_all_persons
    check_write_access!
    relationships.users.delete_all
  end

  def remove_all_groups
    check_write_access!
    relationships.groups.delete_all
  end

  def remove_all_old_relationships(cache)
    # delete all roles that weren't found in the uploaded xml
    cache.each_value do |roles|
      roles.each_value do |object|
        next if [:keep, :new].include? object
        object.destroy
      end
    end
  end

  # Strategy pattern
  class UserUpdater
    def name_for_relationship(r)
      r.user.login
    end

    def xml_element
      'person'
    end

    def ignore?(r)
      !r.user_id
    end

    def id(node)
      node['userid']
    end

    def set_item(record, item)
      record.user = item
    end

    def find!(id)
      User.find_by_login!(id)
    end
  end

  class GroupUpdater
    def name_for_relationship(r)
      r.group.title
    end

    def ignore?(r)
      !r.group_id
    end

    def xml_element
      'group'
    end

    def id(node)
      node['groupid']
    end

    def set_item(record, item)
      record.group = item
    end

    # TODO: this surely does not belong here, this should be handled transparently by Group model
    def find!(id)
      # for groups we create groups transparently (for now, see above)
      group = Group.find_by_title(id)
      return group if group

      # check with LDAP
      raise SaveError, "unknown group '#{id}'" unless CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
      raise SaveError, "unknown group '#{id}' on LDAP server" unless UserLdapStrategy.find_group_with_ldap(id)

      logger.debug "Find and Create group '#{id}' from LDAP"
      Group.create!(title: id)
    end
  end

  def update_generic_relationships(xmlhash)
    # we remember the current relationships in a hash
    cache = Hash.new
    relationships.each do |purr|
      next if @updater.ignore?(purr)
      h = cache[@updater.name_for_relationship(purr)] ||= Hash.new
      h[purr.role.title] = purr
    end

    # in a second step we parse the XML and track in the hash if
    # we keep the relationships
    xmlhash.elements(@updater.xml_element) do |node|
      role = Role.hashed[node['role']]
      raise SaveError, "illegal role name '#{node['role']}'" unless role

      id = @updater.id(node)
      item = @updater.find!(id)

      if cache.has_key? id
        # item has already a role in this model
        pcache = cache[id]
        if pcache.has_key? role.title
          # role already defined, only remove from cache
          pcache[role.title] = :keep
        else
          # new role
          record = relationships.new(role: role)
          @updater.set_item(record, item)
          pcache[role.title] = :new
        end
      else
        record = relationships.new(role: role)
        @updater.set_item(record, item)
        cache[id] = { role.title => :new }
      end
    end

    # all relationships left in cache are to be deleted
    remove_all_old_relationships(cache)
  end

  def update_users_from_xml(xmlhash)
    @updater = UserUpdater.new

    #--- update users ---#
    update_generic_relationships(xmlhash)
  end

  def update_groups_from_xml(xmlhash)
    @updater = GroupUpdater.new

    # update groups
    update_generic_relationships(xmlhash)
  end

  def update_relationships_from_xml(xmlhash)
    update_users_from_xml(xmlhash)
    update_groups_from_xml(xmlhash)
  end
end
