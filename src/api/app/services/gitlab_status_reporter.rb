class GitlabStatusReporter < SCMStatusReporter
  def initialize(event_payload, event_subscription_payload, scm_token, event_type, workflow_run)
    super(event_payload, event_subscription_payload, scm_token, event_type, workflow_run)
  end

  def call
    gitlab_client = Gitlab.client(endpoint: "#{@event_subscription_payload[:api_endpoint]}/api/v4",
                                  private_token: @scm_token)
    # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
    gitlab_client.update_commit_status(@event_subscription_payload[:project_id],
                                       @event_subscription_payload[:commit_sha],
                                       @state,
                                       status_options)
  rescue Gitlab::Error::Error => e
    rescue_with_handler(e) || raise(e)
  end

  private

  # Depending on the SCM, the state is different
  #   GitLab: pending, success, failed, running or canceled
  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      'failed'
    when 'Event::BuildSuccess'
      'success'
    else
      'pending'
    end
  end
end
