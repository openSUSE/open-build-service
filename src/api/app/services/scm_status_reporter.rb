class SCMStatusReporter < SCMExceptionHandler
  attr_accessor :state

  def initialize(event_payload, event_subscription_payload, scm_token, event_type = nil, workflow_run = nil)
    super(event_payload, event_subscription_payload, scm_token, workflow_run)

    @state = event_type.nil? ? 'pending' : scm_final_state(event_type)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def call
    if github?
      github_client = Octokit::Client.new(access_token: @scm_token, api_endpoint: @event_subscription_payload[:api_endpoint])
      # https://docs.github.com/en/rest/reference/repos#create-a-commit-status
      github_client.create_status(@event_subscription_payload[:target_repository_full_name],
                                  @event_subscription_payload[:commit_sha],
                                  @state,
                                  status_options)
    else
      gitlab_client = Gitlab.client(endpoint: "#{@event_subscription_payload[:api_endpoint]}/api/v4",
                                    private_token: @scm_token)
      # https://docs.gitlab.com/ce/api/commits.html#post-the-build-status-to-a-commit
      gitlab_client.update_commit_status(@event_subscription_payload[:project_id],
                                         @event_subscription_payload[:commit_sha],
                                         @state,
                                         status_options)
    end
    @workflow_run.save_scm_report_success(request_context) if @workflow_run.present?
  rescue Octokit::InvalidRepository => e
    package = Package.find_by_project_and_name(@event_payload[:project], @event_payload[:package])
    return if package.blank?

    tokens = Token::Workflow.where(scm_token: @scm_token).pluck(:id)
    return if tokens.none?

    EventSubscription.where(channel: 'scm', token: tokens, package: package).delete_all

    if @workflow_run.present?
      @workflow_run.save_scm_report_failure("Failed to report back to GitHub: #{e.message}",
                                            request_context)
    end
  rescue Octokit::Error, Gitlab::Error::Error => e
    rescue_with_handler(e) || raise(e)
  rescue Faraday::ConnectionFailed => e
    @workflow_run.update_as_failed("Failed to report back to GitHub: #{e.message}")
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def github?
    @event_subscription_payload[:scm] == 'github'
  end

  def status_options
    { context: "OBS: #{@event_payload[:package]} - #{@event_payload[:repository]}/#{@event_payload[:arch]}",
      target_url: Rails.application.routes.url_helpers.package_show_url(@event_payload[:project], @event_payload[:package], host: Configuration.obs_url) }
  end

  # Depending on the SCM, the state is different
  #   GitHub: pending, success, failure or error
  #   GitLab: pending, success, failed, running or canceled
  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      github? ? 'failure' : 'failed'
    when 'Event::BuildSuccess'
      'success'
    else
      'pending'
    end
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
