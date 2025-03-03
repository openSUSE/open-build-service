class Token::RebuildPolicy < TokenPolicy
  def trigger?
    return false unless user.active?
    return PackagePolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)

    ProjectPolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
  end
end
