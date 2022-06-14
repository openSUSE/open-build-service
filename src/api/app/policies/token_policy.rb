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
      # because we cannot use `.or` in scopes that have joins inside
      # see: https://github.com/rails/rails/issues/5545#issuecomment-4632218
      Token.where(id: [scope.owned_tokens(user) + scope.shared_tokens(user)])
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
    record.user == user && !record.type.in?(['Token::Rss'])
  end
end
