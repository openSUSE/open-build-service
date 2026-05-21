class Token::ReleasePolicy < TokenPolicy
  def trigger?
    return false unless user.active?
    return false unless sufficient_permission_on_all_release_targets?
    return PackagePolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Package)

    ProjectPolicy.new(user, record.object_to_authorize).update? if record.object_to_authorize.is_a?(Project)
  end

  private

  # we need to check all release targets upfront to avoid incomplete releases
  def sufficient_permission_on_all_release_targets?
    project = record.object_to_authorize.is_a?(Package) ? record.object_to_authorize.project : record.object_to_authorize
    project.release_targets.where(trigger: 'manual').find_each do |release_target|
      unless ProjectPolicy.new(user, release_target.target_repository.project).update?
        raise Pundit::NotAuthorizedError, query: :trigger?, record: release_target.target_repository.project, reason: :unsufficient_permission_on_release_target
      end
    end
    true
  end
end
