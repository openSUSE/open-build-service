class GitlabStatusReporter < SCMExceptionHandler
  attr_accessor :state, :initial_report, :event_type

  def initialize(event_payload, event_subscription_payload, scm_token, state, workflow_run = nil, event_type = nil, initial_report: false)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = translate_state(state)
    @initial_report = initial_report
    @event_type = event_type
  end

  def call
    gitlab_client = Gitlab.client(endpoint: "#{@workflow_run.api_endpoint}/api/v4",
                                  private_token: @scm_token)
    # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
    gitlab_client.update_commit_status(@workflow_run.project_id,
                                       @workflow_run.commit_sha,
                                       @state,
                                       status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@workflow_run.scm_vendor} value=1")
    end
  rescue Gitlab::Error::Error, OpenSSL::SSL::SSLError => e
    rescue_with_handler(e) || raise(e)
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@workflow_run.scm_vendor},exception=#{e.class} value=1") if @workflow_run.present?
  end

  private

  def translate_state(state)
    return 'failed' if state == 'failure'

    state
  end

  # TODO: extract to a parent class
  def status_options
    if @initial_report
      { context: 'OBS SCM/CI Workflow Integration started',
        target_url: Rails.application.routes.url_helpers.token_workflow_run_url(@workflow_run.token_id, @workflow_run.id, host: Configuration.obs_url) }
    elsif @event_type == 'Event::RequestStatechange'
      { context: "OBS: Request #{@event_payload[:number]}",
        target_url: Rails.application.routes.url_helpers.request_show_url(@event_payload[:number], host: Configuration.obs_url) }
    else
      { context: "OBS: #{@event_payload[:package]} - #{@event_payload[:repository]}/#{@event_payload[:arch]}",
        target_url: Rails.application.routes.url_helpers.package_show_url(@event_payload[:project], @event_payload[:package], host: Configuration.obs_url) }
    end
  end

  # TODO: Extract to a parent class, but only the common keys.
  #       This isn't always the same depending on the SCM.
  def request_context
    {
      api_endpoint: @workflow_run.api_endpoint,
      project_id: @workflow_run.project_id,
      path_with_namespace: @workflow_run.path_with_namespace,
      commit_sha: @workflow_run.commit_sha,
      state: @state,
      status_options: status_options
    }
  end
end
