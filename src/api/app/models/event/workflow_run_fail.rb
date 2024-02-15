module Event
  class WorkflowRunFail < Base
    self.message_bus_routing_key = 'workflow_run.fail'
    self.description = 'Workflow run has failed'
    payload_keys :id, :token_id, :hook_event, :summary, :repository_full_name

    receiver_roles :token_executor

    # Example of subject:
    #   Workflow run failed on Merge request hook
    def subject
      "Workflow run failed on #{payload['hook_event']}"
    end

    def token_executors
      [Token.find_by(id: payload['token_id'], type: 'Token::Workflow')&.executor].compact
    end

    def parameters_for_notification
      super.merge(notifiable_type: 'WorkflowRun', notifiable_id: payload['id'])
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
