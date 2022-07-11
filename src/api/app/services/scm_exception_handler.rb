class SCMExceptionHandler
  include ActiveSupport::Rescuable
  attr_accessor :event_payload, :event_subscription_payload

  rescue_from Octokit::AbuseDetected,
              Octokit::AccountSuspended,
              Octokit::BillingIssue,
              Octokit::BranchNotProtected,
              Octokit::Conflict,
              Octokit::Forbidden,
              Octokit::RepositoryUnavailable,
              Octokit::NotFound,
              Octokit::OneTimePasswordRequired,
              Octokit::Unauthorized,
              Octokit::UnavailableForLegalReasons,
              Octokit::UnsupportedMediaType,
              Octokit::CommitIsNotPartOfPullRequest,
              Octokit::InstallationSuspended,
              Octokit::SAMLProtected,
              Octokit::TooLargeContent,
              Octokit::TooManyLoginAttempts,
              Octokit::UnverifiedEmail,
              Octokit::InvalidRepository,
              Octokit::PathDiffTooLarge,
              Octokit::ServiceUnavailable,
              Octokit::InternalServerError,
              Octokit::UnprocessableEntity,
              Octokit::BadGateway do |exception|
    log_to_workflow_run(exception, 'GitHub') if @workflow_run.present?
  end

  rescue_from Gitlab::Error::Conflict,
              Gitlab::Error::Forbidden,
              Gitlab::Error::InternalServerError,
              Gitlab::Error::MissingCredentials,
              Gitlab::Error::NotFound,
              Gitlab::Error::ServiceUnavailable,
              Gitlab::Error::TooManyRequests,
              Gitlab::Error::Unauthorized,
              Gitlab::Error::BadRequest do |exception|
    log_to_workflow_run(exception, 'GitLab') if @workflow_run.present?
  end

  def initialize(event_payload, event_subscription_payload, scm_token, workflow_run = nil)
    @event_payload = event_payload.deep_symbolize_keys
    @event_subscription_payload = event_subscription_payload.deep_symbolize_keys
    @scm_token = scm_token
    @workflow_run = workflow_run
  end

  private

  def log_to_workflow_run(exception, scm)
    if @event_payload[:project] && @event_payload[:package]
      target_url = Rails.application.routes.url_helpers.package_show_url(@event_payload[:project],
                                                                         @event_payload[:package],
                                                                         host: Configuration.obs_url)
    end
    @workflow_run.save_scm_report_failure("Failed to report back to #{scm}: #{ScmExceptionMessage.for(exception: exception, scm: scm)}",
                                          {
                                            api_endpoint: @event_subscription_payload[:api_endpoint],
                                            target_repository_full_name: @event_subscription_payload[:target_repository_full_name],
                                            commit_sha: @event_subscription_payload[:commit_sha],
                                            state: @state,
                                            status_options: {
                                              context: "OBS: #{@event_payload[:package]} - #{@event_payload[:repository]}/#{@event_payload[:arch]}",
                                              target_url: target_url
                                            }
                                          })
  end
end
