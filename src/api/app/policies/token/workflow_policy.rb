class Token::WorkflowPolicy < TokenPolicy
  def trigger?
    user.is_active?
  end

  def rebuild?
    return PackagePolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)
    return ProjectPolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
  end

  def trigger_service?
    PackagePolicy.new(user, record.object_to_authorize).update?
  end

  def create?
    record.owned_by?(user)
  end

  def index?
    create?
  end

  def show?
    create?
  end

  def update?
    create?
  end
end
