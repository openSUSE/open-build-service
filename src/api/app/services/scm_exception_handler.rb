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
              Octokit::InternalServerError do |exception|
    # FIXME: Inform users about the exceptions
    log(exception)
    log_to_workflow_run(exception, 'GitHub') if @workflow_run.present?
  end

  rescue_from Gitlab::Error::Conflict,
              Gitlab::Error::Forbidden,
              Gitlab::Error::InternalServerError,
              Gitlab::Error::MissingCredentials,
              Gitlab::Error::NotFound,
              Gitlab::Error::ServiceUnavailable,
              Gitlab::Error::TooManyRequests,
              Gitlab::Error::Unauthorized do |exception|
    # FIXME: Inform users about the exceptions
    log(exception)
    log_to_workflow_run(exception, 'GitLab') if @workflow_run.present?
  end

  def initialize(event_payload, event_subscription_payload, scm_token, workflow_run = nil)
    @event_payload = event_payload.deep_symbolize_keys
    @event_subscription_payload = event_subscription_payload.deep_symbolize_keys
    @scm_token = scm_token
    @workflow_run = workflow_run
  end

  private

  def log(exception)
    token = Token::Workflow.find_by(scm_token: @scm_token)
    Rails.logger.error "#{exception.class}: #{exception.message}. TokenID: #{token.id}, User: #{token.user.login}, Event Subscription Payload: #{@event_subscription_payload}"
  end

  def log_to_workflow_run(exception, scm)
    @workflow_run.update_to_fail("Failed to report back to #{scm}: #{exception.message}")
  end
end
