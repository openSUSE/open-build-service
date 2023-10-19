module Event
  class WorkflowRunFail < Base
    self.message_bus_routing_key = 'workflow_run.fail'
    self.description = 'Workflow run has failed'
    payload_keys :id, :token_id

    receiver_roles :token_executor

    def token_executors
      [Token.find_by(id: payload['token_id'], type: 'Token::Workflow')&.executor].compact
    end
  end
end
