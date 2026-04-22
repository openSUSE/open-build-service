module Event
  class GlobalRoleAssigned < Base
    self.description = 'User received an important role'
    self.notification_explanation = "Receive notifications when a user received an important role: #{Role.global_roles.to_sentence(last_word_connector: ' or ')}."

    payload_keys :role, :user, :who
    receiver_roles :admin_moderator_or_staff

    def admin_moderator_or_staffs
      users = case payload['role']
              when 'Admin'
                User.admins
              when 'Staff'
                User.admins.or(User.staff)
              when 'Moderator'
                User.admins.or(User.moderators)
              end
      users.where.not(login: payload['who']).uniq if users
    end

    def parameters_for_notification
      super.merge({ notifiable_type: 'User',
                    notifiable_id: ::User.find_by(login: payload['user']).id,
                    type: 'NotificationUser' })
    end
  end
end
