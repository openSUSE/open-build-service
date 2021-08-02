class Token::ServicePolicy < TokenPolicy
  def trigger?
    return false unless user.is_active?

    PackagePolicy.new(user, record.object_to_authorize).update?
  end
end
