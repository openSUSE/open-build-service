module Event
  class AddedGlobalRole < Base
    self.description = 'User received an important role'
    payload_keys :role, :user, :who

    receiver_roles :colleague

    self.notification_explanation = "Receive notifications when a user received an important role: #{Role.global_roles.to_sentence(last_word_connector: ' or ')}."

    def subject
      return "The user '#{payload['user']}' received the '#{payload['role']}' role" unless payload['who']

      "'#{payload['who']}' gave the '#{payload['role']}' role to the user '#{payload['user']}'"
    end

    # Only users with the same role or admins are notified
    def colleagues
      case payload['role']
      when 'Admin'
        User.admins
      when 'Moderator'
        User.moderators.or(User.admins).uniq
      when 'Staff'
        User.staff.or(User.admins).uniq
      end
    end

    def parameters_for_notification
      super.merge({ notifiable_type: 'User',
                    notifiable_id: ::User.find_by(login: payload['user']).id,
                    type: 'NotificationUser' })
    end
  end
end
