class Token::ServicePolicy < TokenPolicy
  def trigger?
    return false unless user.active?
    return false unless record.object_to_authorize.is_a?(Package)

    Pundit.policy(user, record.object_to_authorize).update?
  end
end
