class CommentLockingValidator < ActiveModel::Validator
  def validate(record)
    commentable = record.commentable
    return unless commentable
    return if maintainer_or_unlocked(record)

    commentable_name = case commentable
                       when Package, Project
                         commentable.class.name.downcase
                       when BsRequest
                         'request'
                       when BsRequestAction
                         'request action'
                       end
    record.errors.add(:base, "This #{commentable_name} is locked for commenting")
  end

  private

  def maintainer_or_unlocked(record)
    user = User.session
    policy = CommentPolicy.new(user, record)
    # Allow maintainers and admins, moderators and staff to create comments despite the lock
    return true if policy.maintainer? || user&.admin? || user&.moderator? || user&.staff?

    # Check if there is a lock, including the parents (project for package and bs_request for bs_request_action)
    !policy.locked?
  end
end
