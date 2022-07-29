class WorkflowRunPolicy < ApplicationPolicy
  class Scope
    def initialize(user, scope, opts = {})
      @user = user
      @scope = scope
      @opts = opts
    end

    def resolve
      token = Token.find_by(id: opts[:token_id])
      raise Pundit::NotAuthorizedError, 'you are not authorized to access those workflow runs' unless token.present? && token.owned_by?(user)
      raise Pundit::NotAuthorizedError, 'the token is not of type workflow' unless token.type == 'Token::Workflow'

      scope.where(token_id: token.id).order(created_at: :desc)
    end

    private

    attr_reader :user, :scope, :opts
  end

  def show?
    record.token.owned_by?(user)
  end
end
