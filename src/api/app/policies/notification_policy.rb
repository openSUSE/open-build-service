class NotificationPolicy < ApplicationPolicy
  def update?
    return true if record.subscriber_type == 'User' && record.subscriber_id == user.id
    return true if record.subscriber_type == 'Group' && record.subscriber_id.include?(user.groups.ids)
  end
end
