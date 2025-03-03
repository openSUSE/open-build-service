class UserBasicStrategy
  def in_group?(user, group)
    user.groups_users.exists?(group_id: group.id)
  end

  def local_role_check(_role, _object)
    false # all is checked, nothing remote
  end

  def local_permission_check(_roles, _object)
    false # all is checked, nothing remote
  end

  def list_groups(user)
    user.groups
  end
end
