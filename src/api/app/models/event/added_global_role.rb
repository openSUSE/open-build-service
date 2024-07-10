module Event
  class AddedGlobalRole < Base
    self.description = 'User received an important role'
    payload_keys :role, :user, :who

    receiver_roles :sibling_role_user

    self.notification_explanation = 'Receive notifications when a user received an important role: Admin, Staff or Moderator.'

    def subject
      return "The user '#{payload['user']}' received the '#{payload['role']}' role" unless payload['who']

      "'#{payload['who']}' gave the '#{payload['role']}' role to the user '#{payload['user']}'"
    end

    def sibling_role_users
      User.with_role(payload['role'])
    end
  end
end
