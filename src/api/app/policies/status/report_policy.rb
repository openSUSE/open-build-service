class Status::ReportPolicy < ApplicationPolicy
  def initialize(user, record)
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record
    @user = user
    @record = record
  end

  def create?
    return false if @user.blank?
    return true if @user.is_admin?

    checkable_containers = case @record.checkable
                           when BsRequest
                             @record.checkable.bs_request_actions.map { |action| request_target_object(action) }
                           when Repository
                             [@record.checkable.project]
                           end

    checkable_containers.all? { |container| write_permission_for_checkable?(container) }
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

  private

  def write_permission_for_checkable?(container)
    container &&
      (container.relationships.users.pluck(:user_id).include?(@user.id) ||
      GroupsUser.where(group: container.relationships.groups.pluck(:group_id), user: @user).exists?)
  end

  def request_target_object(action)
    if action.target_package
      Package.find_by_project_and_name(action.target_project, action.target_package).try(:project)
    elsif action.target_project
      Project.find_by(name: action.target_project)
    end
  end
end
