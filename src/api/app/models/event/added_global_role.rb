module Event
  class AddedGlobalRole < Base
    self.description = 'User received an important role'
    payload_keys :role, :user, :who

    self.notification_explanation = 'Receive notifications when a user received an important role: Admin or Staff or Moderator.'

    def subject
      return "The user '#{payload['user']}' received the '#{payload['role']}' role" unless payload['who']

      "'#{payload['who']}' gave the '#{payload['role']}' role to the user '#{payload['user']}'"
    end
  end
end
