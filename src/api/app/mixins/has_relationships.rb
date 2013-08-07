# a model that has relationships - e.g. a project and a package
module HasRelationships

  def self.included(base)
    base.class_eval do
      has_many :relationships, dependent: :destroy
    end
  end

  class SaveError < APIException
  end

  def add_user(user, role)
    Relationship.add_user(self, user, role)
  end

  def add_group(group, role)
    Relationship.add_group(self, group, role)
  end

  def users_and_roles
    relationships.joins(:role, :user).order("role_name, login").
        pluck("users.login as login, roles.title AS role_name")
  end

  def groups_and_roles
    relationships.joins(:role, :group).order("role_name, title").
        pluck("groups.title as title", "roles.title as role_name")
  end

  def render_relationships(xml)
    users_and_roles.each do |user, role|
      xml.person(userid: user, role: role)
    end

    groups_and_roles.each do |group, role|
      xml.group(groupid: group, role: role)
    end
  end

  def user_has_role?(user, role)
    return true if self.relationships.where(role_id: role.id, user_id: user.id).exists?
    return self.relationships.where(role_id: role).joins(:groups_users).where(groups_users: { user_id: user.id }).exists?
  end

  def remove_role(what, role)
    check_write_access!

    if what.kind_of? Group
      rel = self.relationships.where(group_id: what.id)
    else
      rel = self.relationships.where(user_id: what.id)
    end
    rel = rel.where(role_id: role.id) if role
    self.transaction do
      rel.delete_all
      write_to_backend
    end
  end

  def add_role(what, role)
    check_write_access!

    self.transaction do
      if what.kind_of? Group
        self.relationships.create!(role: role, group: what)
      else
        self.relationships.create!(role: role, user: what)
      end
      write_to_backend
    end
  end

  def remove_all_persons
    check_write_access!
    self.relationships.users.delete_all
  end

  def remove_all_groups
    check_write_access!
    self.relationships.groups.delete_all
  end

  def remove_all_old_relationships(cache)
    # delete all roles that weren't found in the uploaded xml
    cache.each do |user, roles|
      roles.each do |role, object|
        next if [:keep, :new].include? object
        object.delete
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

    def id(node)
      node['userid']
    end

    def set_item(record, item)
      record.user = item
    end

    def find!(id)
      User.get_by_login(id)
    end
  end

  class GroupUpdater
    def name_for_relationship(r)
      r.group.title
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
      if CONFIG['ldap_mode'] == :on && CONFIG['ldap_group_support'] == :on
        if User.find_group_with_ldap(id)
          logger.debug "Find and Create group '#{id}' from LDAP"
          return Group.create!(title: id)
        else
          raise SaveError, "unknown group '#{id}' on LDAP server"
        end
      else
        raise SaveError, "unknown group '#{id}'"
      end
    end
  end

  def update_generic_relationships(xmlhash, relation)

    # we remember the current relationships in a hash
    cache = Hash.new
    relation.each do |purr|
      h = cache[@updater.name_for_relationship(purr)] ||= Hash.new
      h[purr.role.title] = purr
    end

    # in a second step we parse the XML and track in the hash if
    # we keep the relationships
    xmlhash.elements(@updater.xml_element) do |node|

      unless role = Role.rolecache[node['role']]
        raise SaveError, "illegal role name '#{node['role']}'"
      end

      id = @updater.id(node)
      item = @updater.find!(id)

      if cache.has_key? id
        # item has already a role in this model
        pcache = cache[id]
        if pcache.has_key? role.title
          #role already defined, only remove from cache
          pcache[role.title] = :keep
        else
          #new role
          record = self.relationships.new(role: role)
          @updater.set_item(record, item)
          pcache[role.title] = :new
        end
      else
        record = self.relationships.new(role: role)
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
    update_generic_relationships(xmlhash, self.relationships.users)
  end

  def update_groups_from_xml(xmlhash)
    @updater = GroupUpdater.new

    # update groups
    update_generic_relationships(xmlhash, self.relationships.groups)
  end

  def update_relationships_from_xml(xmlhash)
    update_users_from_xml(xmlhash)
    update_groups_from_xml(xmlhash)
  end
end
