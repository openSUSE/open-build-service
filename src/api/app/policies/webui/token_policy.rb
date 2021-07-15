class Webui::TokenPolicy < ApplicationPolicy
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

  def destroy?
    # TODO: when trigger_workflow is rolled out, remove the Flipper check
    record.user == user && record.type != 'Token::Rss' && Flipper.enabled?(:trigger_workflow, user)
  end
end
