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
