class CommentPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def destroy?
    return false if @user.blank?

    # Admins can always delete all comments
    return true if @user.is_admin?

    # Users can always delete their own comments - or if the user of the comment is deleted
    return true if @user == @record.user || @record.user.is_nobody?

    case @record.commentable_type
    when 'Package'
      @user.has_local_permission?('change_package', @record.commentable)
    when 'Project'
      @user.has_local_permission?('change_project', @record.commentable)
    when 'BsRequest'
      @record.commentable.is_target_maintainer?(@user)
    end
  end
end
