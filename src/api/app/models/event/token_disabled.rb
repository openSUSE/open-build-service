module Event
  class TokenDisabled < Base
    self.description = 'Token was disabled due to authorization errors'
    payload_keys :token_id, :token_name, :scm_vendor, :workflow_run_id

    receiver_roles :token_executor, :token_member
    delegate :members, to: :token, prefix: true

    self.notification_explanation = 'Receive notifications when a workflow token is disabled due to SCM authorization errors.'

    def subject
      vendor = payload['scm_vendor']&.capitalize || 'SCM'
      "Your #{vendor} workflow token was disabled due to authorization errors"
    end

    def token_executors
      [token&.executor].compact
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'Token::Workflow', notifiable_id: payload['token_id'], type: 'NotificationToken')
    end

    def event_object
      token
    end

    private

    def token
      Token.find_by(id: payload['token_id'], type: 'Token::Workflow')
    end
  end
end
