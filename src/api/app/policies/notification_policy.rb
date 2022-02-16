class NotificationPolicy < ApplicationPolicy
  class Scope < Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, reason: ApplicationPolicy::ANONYMOUS_USER if user.nil? || user.is_nobody?

      super(user, scope)
    end

    def resolve
      # TODO: There are no notifications anymore with subscriber_type 'Group' since we create a notification for every group member instead
      scope.where("(subscriber_type = 'User' AND subscriber_id = ?) OR (subscriber_type = 'Group' AND subscriber_id IN (?))",
                  user, user.groups.select(:id))
    end
  end

  def update?
    return true if record.subscriber_type == 'User' && record.subscriber_id == user.id
    return true if record.subscriber_type == 'Group' && user.groups.ids.includes?(record.subscriber_id)

    false
  end
end
