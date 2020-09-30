class ApplicationPolicy
  attr_reader :user, :record

  ANONYMOUS_USER = :anonymous_user

  def initialize(user, record, opts = {})
    ensure_logged_in!(user, opts)
    raise Pundit::NotAuthorizedError, 'must be logged in' unless user || opts[:user_optional]
    raise Pundit::NotAuthorizedError, 'record does not exist' unless record

    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  private

  def ensure_logged_in!(user, opts)
    raise Pundit::NotAuthorizedError, reason: ANONYMOUS_USER if opts[:ensure_logged_in] && (user.nil? || user.is_nobody?)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
