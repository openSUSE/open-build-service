class CommentPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    return false if user.blank? || user.is_nobody?
    return true if maintainer? || important_user?
    return false if user.blocked_from_commenting

    !locked?
  end

  def destroy?
    # Can't destroy comments without being logged in or a comment that was already deleted (ie. Comment#user is nobody)
    return false if user.blank? || record.user.is_nobody?
    # Admins can always delete all comments
    return true if user.is_admin?

    # Users can always delete their own comments
    return true if user == record.user

    maintainer?
  end

  def update?
    return false if user.blank? || user.is_nobody?

    user == record.user
  end

  def reply?
    return false if record.user.is_nobody?

    create?
  end

  # Only logged-in Admins/Staff members or user with moderator role can moderate comments
  def moderate?
    return false if record.user.is_nobody? # soft-deleted comments
    return false if user == record.user
    return true if user.try(:is_moderator?) || user.try(:is_admin?) || user.try(:is_staff?)

    false
  end

  def maintainer?
    return false unless user

    case record.commentable_type
    when 'Package'
      user.has_local_permission?('change_package', record.commentable)
    when 'Project'
      user.has_local_permission?('change_project', record.commentable)
    when 'BsRequest'
      record.commentable.is_target_maintainer?(user)
    end
  end

  def locked?
    case record.commentable
    when Package
      record.commentable.project.comment_lock.present? || record.commentable.comment_lock.present?
    when BsRequestAction
      record.commentable.bs_request.comment_lock.present? || record.commentable.comment_lock.present?
    else
      record.commentable.comment_lock.present?
    end
  end

  def history?
    return false unless Flipper.enabled?(:content_moderation, user)
    # Always display the comment history if the user is admin or moderator
    return true if user.is_admin? || user.is_staff? || user.is_moderator?

    # Don't display history for moderated and soft deleted comments
    !(record.moderated? || record.user.is_nobody?)
  end

  private

  def important_user?
    user.is_admin? || user.is_moderator? || user.is_staff?
  end
end
