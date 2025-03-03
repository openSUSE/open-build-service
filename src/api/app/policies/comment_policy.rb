class CommentPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def create?
    return false if user.blank? || user.nobody?
    return true if maintainer? || important_user?
    return false if user.censored

    !locked?
  end

  def destroy?
    # Can't destroy comments without being logged in or a comment that was already deleted (ie. Comment#user is nobody)
    return false if user.blank? || record.user.nobody?
    # Admins can always delete all comments
    return true if user.admin?

    # Users can always delete their own comments
    return true if user == record.user

    maintainer?
  end

  def update?
    return false if user.blank? || user.nobody?

    user == record.user
  end

  def reply?
    return false if record.user.nobody?

    create?
  end

  # Only logged-in Admins/Staff members or user with moderator role can moderate comments
  def moderate?
    return false if record.user.nobody? # soft-deleted comments
    return false if user == record.user
    return true if user.try(:moderator?) || user.try(:admin?) || user.try(:staff?)

    false
  end

  def maintainer?
    return false unless user

    case record.commentable_type
    when 'Package'
      user.local_permission?('change_package', record.commentable)
    when 'Project'
      user.local_permission?('change_project', record.commentable)
    when 'BsRequest'
      record.commentable.target_maintainer?(user)
    end
  end

  def locked?
    case record.commentable
    when Package
      record.commentable.project.comment_lock.present? || record.commentable.comment_lock.present?
    when BsRequestAction
      record.commentable.bs_request.comment_lock.present? || record.commentable.comment_lock.present?
    when Report
      false
    else
      record.commentable.comment_lock.present?
    end
  end

  def history?
    return false unless Flipper.enabled?(:content_moderation, user)
    # Always display the comment history if the user is admin or moderator
    return true if user.admin? || user.staff? || user.moderator?

    # Don't display history for moderated and soft deleted comments
    !(record.moderated? || record.user.nobody?)
  end

  private

  def important_user?
    user.admin? || user.moderator? || user.staff?
  end
end
