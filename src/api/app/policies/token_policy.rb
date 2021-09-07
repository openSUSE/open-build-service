class TokenPolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, opts.merge(ensure_logged_in: true))
  end

  class Scope < Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER if user.nil? || user.is_nobody?

      super(user, scope)
    end

    def resolve
      scope.where(user: user).where.not(type: 'Token::Rss').includes(package: :project)
    end
  end

  def new?
    # TODO: when trigger_workflow is rolled out, uncomment the next line and remove the Flipper check
    # true
    Flipper.enabled?(:trigger_workflow, user)
  end

  def edit?
    update?
  end

  def update?
    record.user == user && Flipper.enabled?(:trigger_workflow, user)
  end

  def create?
    # TODO: when trigger_workflow is rolled out, remove the Flipper check
    record.user == user && record.type != 'Token::Rss' && Flipper.enabled?(:trigger_workflow, user)
  end

  def destroy?
    create?
  end

  def webui_trigger?
    record.user == user && !record.type.in?(['Token::Workflow', 'Token::Rss'])
  end

  def show?
    webui_trigger?
  end
end
