module Event
  class GlobalRoleAssigned < Base
    self.description = 'User received an important role'
    self.notification_explanation = "Receive notifications when a user received an important role: #{Role.global_roles.to_sentence(last_word_connector: ' or ')}."

    payload_keys :role, :user, :who
    receiver_roles :admin_moderator_or_staff

    def admin_moderator_or_staffs
      case payload['role']
      when 'Admin'
        User.admins
      when 'Moderator'
        User.moderators.or(User.admins).uniq
      when 'Staff'
        User.staff.or(User.admins).uniq
      end
    end
  end
end
