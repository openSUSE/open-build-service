class Token::WorkflowPolicy < TokenPolicy
  # TODO: remove the second half of the condition when `trigger_workflow` feature is rolled out
  def trigger?
    user.is_active? && Flipper.enabled?(:trigger_workflow, user)
  end

  def rebuild?
    return PackagePolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)
    return ProjectPolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
  end
end
