class GiteaStatusReporter < SCMExceptionHandler
  attr_accessor :state, :initial_report

  def initialize(event_payload, event_subscription_payload, scm_token, state, workflow_run = nil, initial_report: false)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = state
    @initial_report = initial_report
  end

  def call
    gitea_client = GiteaAPI::V1::Client.new(api_endpoint: @event_subscription_payload[:api_endpoint],
                                            token: @scm_token)
    owner, repository_name = @event_subscription_payload[:target_repository_full_name].split('/')
    gitea_client.create_commit_status(owner: owner, repo: repository_name,
                                      sha: @event_subscription_payload[:commit_sha],
                                      state: @state, **status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@event_subscription_payload[:scm]} value=1")
    end
  rescue Faraday::ConnectionFailed => e
    @workflow_run.save_scm_report_failure("Failed to report back to Gitea: #{e.message}", request_context) if @workflow_run.present?
  rescue GiteaAPI::V1::Client::GiteaApiError => e
    rescue_with_handler(e) || raise(e)
  ensure
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@event_subscription_payload[:scm]},exception=#{e.class} value=1") if e.present? && @workflow_run.present?
  end

  private

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

  # TODO: extract to a parent class
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
