# Items refer to either Projects or Packages
class InvolvedItemsFinder
  # relation can also be for projects, so passing Project.all is a viable option
  def initialize(relation = Package.all)
    @relation = relation
  end

  def for_roles(role_ids)
    @relation.joins(:relationships).where(relationships: { role_id: role_ids })
  end

  def for_user(user_id)
    @relation.joins(:relationships).where(relationships: { user_id: user_id })
  end

  def for_groups(group_ids)
    @relation.joins(:relationships).where(relationships: { group_id: group_ids })
  end

  def for_name(search_text)
    @relation.where('LOWER(name) LIKE ?', "%#{search_text.downcase}%")
  end
end
