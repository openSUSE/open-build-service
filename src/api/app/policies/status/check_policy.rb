class Status::CheckPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    return false if @user.blank?
    return true if @user.is_admin?

    case @record.checkable
    when BsRequest
      checkable_container = request_target_object
    when Status::RepositoryPublish
      checkable_container = @record.checkable
    end

    return false unless checkable_container

    checkable_container.relationships.users.pluck(:user_id).include?(@user.id) || checkable_container.groups_users.pluck(:user_id).include?(@user.id)
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def index?
    true
  end

  def show?
    index?
  end

  def request_target_object
    target_project = @record.checkable.target_project
    target_package = @record.checkable.target_package

    if target_package
      Package.find_by_project_and_name(target_project, target_package).try(:project)
    elsif @record.checkable.target_project
      Project.find_by(name: target_project)
    end
  end
end
