class NotificationCommentPolicy < ApplicationPolicy
  def update?
    record.subscriber == user
  end
end
