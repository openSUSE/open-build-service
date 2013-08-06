# a model that has relationships - e.g. a project and a package
module HasRelationships

  def add_user( user, role )
    Relationship.add_user(self, user, role)
  end

  def add_group( group, role )
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

end
