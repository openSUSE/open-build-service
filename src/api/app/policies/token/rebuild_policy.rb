class Token::RebuildPolicy < TokenPolicy
  def trigger?
    return false unless user.is_active?

    return PackagePolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)
    return ProjectPolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
  end
end
