class Webui::StatusMessagePolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, opts.merge(ensure_logged_in: true))
  end

  def create?
    user.is_admin? || user.is_staff?
  end

  def new?
    create?
  end

  def destroy?
    create?
  end

  def acknowledge?
    true
  end
end
