class GitlabStatusReporter < SCMExceptionHandler
  attr_accessor :state, :initial_report

  def initialize(event_payload, event_subscription_payload, scm_token, state, workflow_run = nil, initial_report: false)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = state
    @initial_report = initial_report
  end

  def call
    gitlab_client = Gitlab.client(endpoint: "#{@event_subscription_payload[:api_endpoint]}/api/v4",
                                  private_token: @scm_token)
    # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
    gitlab_client.update_commit_status(@event_subscription_payload[:project_id],
                                       @event_subscription_payload[:commit_sha],
                                       @state,
                                       status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@event_subscription_payload[:scm]} value=1")
    end
  rescue Gitlab::Error::Error => e
    rescue_with_handler(e) || raise(e)
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@event_subscription_payload[:scm]},exception=#{e.class} value=1") if @workflow_run.present?
  end

  # TODO: extract to a parent class
  def status_options
    if @initial_report
      { context: 'OBS SCM/CI Workflow Integration started',
        target_url: Rails.application.routes.url_helpers.token_workflow_run_url(@workflow_run.token_id, @workflow_run.id, host: Configuration.obs_url) }
    else
      { context: "OBS: #{@event_payload[:package]} - #{@event_payload[:repository]}/#{@event_payload[:arch]}",
        target_url: Rails.application.routes.url_helpers.package_show_url(@event_payload[:project], @event_payload[:package], host: Configuration.obs_url) }
    end
  end

  # TODO: Extract to a parent class, but only the common keys.
  #       This isn't always the same depending on the SCM.
  def request_context
    {
      api_endpoint: @event_subscription_payload[:api_endpoint],
      project_id: @event_subscription_payload[:project_id],
      path_with_namespace: @event_subscription_payload[:path_with_namespace],
      commit_sha: @event_subscription_payload[:commit_sha],
      state: @state,
      status_options: status_options
    }
  end
end
