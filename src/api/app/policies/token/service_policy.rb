class Token::ServicePolicy < TokenPolicy
  def trigger?
    return false unless user.active?

    object = record.object_to_authorize
    if object.is_a?(Project) && object.scmsync.present?
      ProjectPolicy.new(user, object).update?
    else
      PackagePolicy.new(user, object).update?
    end
  end
end
