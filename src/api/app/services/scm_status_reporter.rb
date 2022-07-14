class SCMStatusReporter < SCMExceptionHandler
  attr_accessor :state

  def initialize(event_payload, event_subscription_payload, scm_token, event_type = nil, workflow_run = nil)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = event_type.nil? ? 'pending' : scm_final_state(event_type)
  end

  def call
    # Should use either GithubStatusReporter or GitlabStatusReporter
    raise AbstractMethodCalled
  end

  private

  def status_options
    { context: "OBS: #{@event_payload[:package]} - #{@event_payload[:repository]}/#{@event_payload[:arch]}",
      target_url: Rails.application.routes.url_helpers.package_show_url(@event_payload[:project], @event_payload[:package], host: Configuration.obs_url) }
  end

  def request_context
    {
      api_endpoint: @event_subscription_payload[:api_endpoint],
      target_repository_full_name: @event_subscription_payload[:target_repository_full_name],
      commit_sha: @event_subscription_payload[:commit_sha],
      state: @state,
      status_options: status_options
    }
  end
end
