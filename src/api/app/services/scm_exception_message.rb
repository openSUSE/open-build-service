class SCMExceptionMessage
  GITHUB_EXCEPTIONS = {
    Octokit::AbuseDetected =>
      'You have triggered an abuse detection mechanism and have been temporarily blocked from content creation. Please retry your request again later.',
    Octokit::AccountSuspended =>
      'Sorry. Your account is suspended.',
    Octokit::BillingIssue =>
      'The repository has been disabled due to a billing issue with the owner account.',
    Octokit::BranchNotProtected =>
      'This branch is not protected.',
    Octokit::Forbidden =>
      'Request is forbidden.',
    Octokit::RepositoryUnavailable =>
      'Repository access is blocked.',
    Octokit::NotFound =>
      'Content not found.',
    Octokit::OneTimePasswordRequired =>
      'Must specify two-factor authentication OTP code.',
    Octokit::Unauthorized =>
      'Unauthorized request. Please check your credentials again.',
    Octokit::UnavailableForLegalReasons =>
      'The contents you are requesting are not available for legal reasons.',
    Octokit::UnsupportedMediaType =>
      'Unsupported Media Type. See: https://docs.github.com/rest',
    Octokit::CommitIsNotPartOfPullRequest =>
      'end_commit_oid is not part of the pull request.',
    Octokit::InstallationSuspended =>
      'This installation has been suspended. See: https://docs.github.com/rest/reference/apps#create-an-installation-access-token-for-an-app',
    Octokit::SAMLProtected =>
      'Resource protected by organization SAML enforcement. You must grant your personal token access to this organization.',
    Octokit::TooLargeContent =>
      'The content size is too large. This API returns blobs up to 1 MB in size.',
    Octokit::TooManyLoginAttempts =>
      'Maximum number of login attempts exceeded. Please try again later.',
    Octokit::UnverifiedEmail =>
      'The email you are using is unverified. At least one email address must be verified to do that.',
    Octokit::InvalidRepository =>
      'Use the user/repo (String) format, or the repository ID (Integer), or a hash containing :repo and :user keys. Example: sferik/octokit.',
    Octokit::PathDiffTooLarge =>
      'Action can not be performed. File too large.',
    Octokit::UnprocessableEntity =>
      'Server is unable to process the contained instructions. Please modify your request and try again.',
    Octokit::InternalServerError => # 500
      'Internal error. Please try again later.',
    Octokit::NotImplemented =>      # 501
      'The server does not support the functionality required to fulfill the request. Please modify your request and try again.',
    Octokit::BadGateway =>          # 502
      'Bad gateway. Please try again later.',
    Octokit::ServiceUnavailable =>  # 503
      'Service is unavailable. Please try again later.',
    Octokit::ServerError =>         # 500..599
      'Generic server error. Please try again later.'
  }.freeze

  GITLAB_EXCEPTIONS = {
    Gitlab::Error::BadGateway =>
      'Bad gateway. Please try again later.',
    Gitlab::Error::Conflict =>
      'The request could not be completed due to a conflict with the current state of the target resource.',
    Gitlab::Error::Forbidden =>
      'Request forbidden.',
    Gitlab::Error::InternalServerError =>
      'Internal error. Please try again later.',
    Gitlab::Error::MissingCredentials =>
      'Please check your credentials again and set an endpoint to API.',
    Gitlab::Error::NotFound =>
      'Project Not Found.',
    Gitlab::Error::ServiceUnavailable =>
      'Service is unavailable. Please try again later.',
    Gitlab::Error::TooManyRequests =>
      'Maximum number of requests exceeded. Please try again later.',
    Gitlab::Error::Unauthorized =>
      'Unauthorized request. Please check your credentials again.',
    Gitlab::Error::BadRequest =>
      'Bad request. Please modify your request and try again.'
  }.freeze

  def self.for(exception:, scm:)
    case scm
    when 'GitHub'
      message = GITHUB_EXCEPTIONS[exception.class]
    when 'GitLab'
      message = GITLAB_EXCEPTIONS[exception.class]
    end
    return exception.message if message.nil?

    message
  end
end
