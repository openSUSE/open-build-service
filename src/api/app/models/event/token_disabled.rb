module Event
  class TokenDisabled < Base
    self.description = 'SCM/CI Token disabled due to authorization failure'
    payload_keys :id, :token_id, :scm_vendor, :summary, :token_description

    receiver_roles :token_executor, :token_member
    delegate :members, to: :token, prefix: true

    self.notification_explanation = 'Receive notifications when an SCM/CI integration token is disabled due to authorization problems.'

    # Example of subject:
    #   GitHub workflow token disabled
    def subject
      vendor_map = { 'github' => 'GitHub', 'gitlab' => 'GitLab', 'gitea' => 'Gitea' }
      vendor = vendor_map[payload['scm_vendor']] || payload['scm_vendor']&.capitalize || 'SCM'
      "#{vendor} workflow token disabled"
    end

    def token_executors
      [token&.executor].compact
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Token::Workflow', notifiable_id: payload['token_id'], type: 'NotificationToken')
    end

    def event_object
      Token.find_by(id: payload['token_id'])
    end

    private

    def token
      Token.find_by(id: payload['token_id'], type: 'Token::Workflow')
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
