class Token::ReleasePolicy < TokenPolicy
  def trigger?
    return false unless user.is_active?
    return false unless sufficient_permission_on_all_release_targets?

    PackagePolicy.new(user, record.object_to_authorize).update?
  end

  private

  # we need to check all release targets upfront to avoid incomplete releases
  def sufficient_permission_on_all_release_targets?
    record.object_to_authorize.project.release_targets.where(trigger: 'manual').each do |release_target|
      unless ProjectPolicy.new(user, release_target.target_repository.project).update?
        raise Pundit::NotAuthorizedError, query: :trigger?, record: release_target.target_repository.project, reason: :unsufficient_permission_on_release_target
      end
    end
  end
end
