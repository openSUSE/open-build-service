class CommentLockPolicy < ApplicationPolicy
  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    return false if record.is_a?(Report)

    return true if user.moderator? || user.admin?

    case record
    # Maintainers of Package or Project can lock comments
    when Package, Project
      return record.maintainers.include?(user)
    # Request receivers (maintainers of target package) can also lock comments
    when BsRequest
      return record.target_maintainer?(user)
    when BsRequestAction
      return record.bs_request.target_maintainer?(user)
    end

    false
  end

  def destroy?
    create?
  end
end
