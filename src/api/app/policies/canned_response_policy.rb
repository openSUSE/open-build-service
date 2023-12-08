class CannedResponsePolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, { ensure_logged_in: true }.merge(opts))
  end

  class Scope < Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER if user.nil? || user.is_nobody?

      super(user, scope)
    end

    def resolve
      CannedResponse.where(user:)
    end
  end

  def edit?
    return false unless Flipper.enabled?(:content_moderation, user)

    record.user == user
  end

  def update?
    return false unless Flipper.enabled?(:content_moderation, user)

    record.user == user
  end

  def create?
    return false unless Flipper.enabled?(:content_moderation, user)

    record.user == user
  end

  def destroy?
    return false unless Flipper.enabled?(:content_moderation, user)

    record.user == user
  end
end
