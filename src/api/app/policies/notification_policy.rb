class NotificationPolicy < ApplicationPolicy
  def update?
    record.subscriber == user
  end
end
