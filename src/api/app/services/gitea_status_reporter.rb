class GiteaStatusReporter < SCMExceptionHandler
  attr_accessor :state, :initial_report, :event_type

  def initialize(event_payload, event_subscription_payload, scm_token, state, workflow_run = nil, event_type = nil, initial_report: false)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = state
    @initial_report = initial_report
    @event_type = event_type
  end

  def call
    gitea_client = GiteaAPI::V1::Client.new(api_endpoint: @workflow_run.api_endpoint,
                                            token: @scm_token)
    owner, repository_name = @workflow_run.target_repository_full_name.split('/')
    gitea_client.create_commit_status(owner: owner, repo: repository_name,
                                      sha: @workflow_run.commit_sha,
                                      state: @state, **status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@workflow_run.scm_vendor} value=1")
    end
  rescue GiteaAPI::V1::Client::GiteaApiError => e
    rescue_with_handler(e) || raise(e)
  ensure
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@workflow_run.scm_vendor},exception=#{e.class} value=1") if e.present? && @workflow_run.present?
  end

  private

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

  # TODO: extract to a parent class
  def request_context
    {
      api_endpoint: @workflow_run.api_endpoint,
      target_repository_full_name: @workflow_run.target_repository_full_name,
      commit_sha: @workflow_run.commit_sha,
      state: @state,
      status_options: status_options
    }
  end
end
