class CommentPolicy < ApplicationPolicy
  def initialize(user, record)
    super(user, record, user_optional: true)
  end

  def destroy?
    # Can't destroy comments without being logged in or a comment that was already deleted (ie. Comment#user is nobody)
    return false if user.blank? || record.user.is_nobody?
    # Admins can always delete all comments
    return true if user.is_admin?

    # Users can always delete their own comments
    return true if user == record.user

    case record.commentable_type
    when 'Package'
      user.has_local_permission?('change_package', record.commentable)
    when 'Project'
      user.has_local_permission?('change_project', record.commentable)
    when 'BsRequest'
      record.commentable.is_target_maintainer?(user)
    end
  end

  def update?
    return false if user.blank? || user.is_nobody?

    user == record.user
  end

  def reply?
    !(user.blank? || user.is_nobody? || record.user.is_nobody?)
  end
end
