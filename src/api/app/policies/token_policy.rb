class TokenPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # because we cannot use `.or` in scopes that have joins inside
      # see: https://github.com/rails/rails/issues/5545#issuecomment-4632218
      Token.where(id: [scope.owned_tokens(user) + scope.shared_tokens(user) + scope.group_shared_tokens(user)])
    end
  end

  def update?
    create?
  end

  def create?
    record.owned_by?(user)
  end

  def destroy?
    create?
  end
end
