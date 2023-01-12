class Webui::StatusMessagePolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, { ensure_logged_in: true }.merge(opts))
  end

  def create?
    user.is_admin? || user.is_staff?
  end

  def index?
    create?
  end

  def new?
    create?
  end

  def edit?
    create?
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  def acknowledge?
    true
  end
end
