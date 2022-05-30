class GithubStatusReporter < SCMStatusReporter
  def initialize(event_payload, event_subscription_payload, scm_token, event_type, workflow_run)
    super(event_payload, event_subscription_payload, scm_token, event_type, workflow_run)
  end

  def call
    github_client = Octokit::Client.new(access_token: @scm_token,
                                        api_endpoint: @event_subscription_payload[:api_endpoint])
    # https://docs.github.com/en/rest/reference/repos#create-a-commit-status
    github_client.create_status(@event_subscription_payload[:target_repository_full_name],
                                @event_subscription_payload[:commit_sha],
                                @state,
                                status_options)
  rescue Octokit::InvalidRepository => e
    package = Package.find_by_project_and_name(@event_payload[:project], @event_payload[:package])
    return if package.blank?

    tokens = Token::Workflow.where(scm_token: @scm_token).pluck(:id)
    return if tokens.none?

    EventSubscription.where(channel: 'scm', token: tokens, package: package).delete_all

    if @workflow_run.present?
      @workflow_run.save_scm_report_failure("Failed to report back to GitHub: #{e.message}",
                                            {
                                              api_endpoint: @event_subscription_payload[:api_endpoint],
                                              target_repository_full_name: @event_subscription_payload[:target_repository_full_name],
                                              commit_sha: @event_subscription_payload[:commit_sha],
                                              state: @state,
                                              status_options: status_options
                                            })
    end
  rescue Octokit::Error => e
    rescue_with_handler(e) || raise(e)
  end

  private

  # Depending on the SCM, the state is different
  #   GitHub: pending, success, failure or error
  def scm_final_state(event_type)
    case event_type
    when 'Event::BuildFail'
      'failure'
    when 'Event::BuildSuccess'
      'success'
    else
      'pending'
    end
  end
end
