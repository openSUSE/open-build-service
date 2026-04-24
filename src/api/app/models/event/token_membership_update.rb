module Event
  class TokenMembershipUpdate < Base
    self.description = 'Share or unshare token with user or group'
    self.notification_explanation = 'Receive a notification when the user or a group the user belongs to is added to or removed from a token.'

    payload_keys :token_id, :user_login, :group_title, :who, :action

    receiver_roles :updated_token_member

    def parameters_for_notification
      super.merge(notifiable_type: 'Token::Workflow',
                  notifiable_id: payload['token_id'],
                  type: 'NotificationTokenWorkflow')
    end

    def updated_token_members
      return User.where(login: payload['user_login']) if payload['user_login'].present?

      group_users = ::Group.find_by(title: payload['group_title'])&.users

      group_users&.where&.not(login: payload['who'])
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
