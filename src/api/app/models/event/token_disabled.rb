module Event
  class TokenDisabled < Base
    self.description = 'Workflow token automatically disabled'
    payload_keys :id, :token_id

    receiver_roles :token_executor, :token_member
    delegate :members, to: :token, prefix: true

    self.notification_explanation = 'Receive notifications for workflow tokens disabled automatically.'

    def subject
      "Workflow Token '#{token.description}' was disabled automatically"
    end

    def token_executors
      [token&.executor].compact
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'WorkflowRun', notifiable_id: payload['id'], type: 'NotificationWorkflowRun')
    end

    def event_object
      WorkflowRun.find(payload['id'])
    end

    private

    def token
      Token.find(payload['token_id'])
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
