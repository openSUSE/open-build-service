class GithubStatusReporter < SCMExceptionHandler
  attr_accessor :state, :initial_report

  def initialize(event_payload, event_subscription_payload, scm_token, state, workflow_run = nil, initial_report: false)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = state
    @initial_report = initial_report
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def call
    github_client = Octokit::Client.new(access_token: @scm_token,
                                        api_endpoint: @event_subscription_payload[:api_endpoint])
    # https://docs.github.com/en/rest/reference/repos#create-a-commit-status
    github_client.create_status(@event_subscription_payload[:target_repository_full_name],
                                @event_subscription_payload[:commit_sha],
                                @state,
                                status_options)
    if @workflow_run.present?
      @workflow_run.save_scm_report_success(request_context)
      RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=success,scm=#{@event_subscription_payload[:scm]} value=1")
    end
  rescue Octokit::InvalidRepository => e
    package = Package.find_by_project_and_name(@event_payload[:project], @event_payload[:package])
    return if package.blank?

    tokens = Token::Workflow.where(scm_token: @scm_token).pluck(:id)
    return if tokens.none?

    EventSubscription.where(channel: 'scm', token: tokens, package: package).delete_all

    @workflow_run.save_scm_report_failure("Failed to report back to GitHub: #{e.message}", request_context) if @workflow_run.present?
  rescue Octokit::Error => e
    rescue_with_handler(e) || raise(e)
  rescue Faraday::ConnectionFailed => e
    @workflow_run.save_scm_report_failure("Failed to report back to GitHub: #{e.message}", request_context) if @workflow_run.present?
  ensure
    RabbitmqBus.send_to_bus('metrics', "scm_status_report,status=fail,scm=#{@event_subscription_payload[:scm]},exception=#{e.class} value=1") if e.present? && @workflow_run.present?
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

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
