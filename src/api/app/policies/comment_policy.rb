class CommentPolicy < ApplicationPolicy
  def destroy?
    return true if @user.is_admin? || owner? || deleted?

    case @record.commentable_type
    when 'Package'
      @user.has_local_permission?('change_package', @record.package)
    when 'Project'
      @user.has_local_permission?('change_project', @record.project)
    when 'BsRequest'
      @record.is_target_maintainer?(@user)
    end
  end

  private

  def deleted?
    @record.user.is_nobody?
  end

  def owner?
    @user == @record.user
  end
end
