module SCMAuthExceptions
  EXCEPTIONS = [
    GiteaAPI::V1::Client::UnauthorizedError,
    GiteaAPI::V1::Client::ForbiddenError,
    Gitlab::Error::Unauthorized,
    Gitlab::Error::Forbidden,
    Gitlab::Error::MissingCredentials,
    Octokit::Unauthorized,
    Octokit::Forbidden
  ].freeze

  def self.include?(error)
    EXCEPTIONS.any? { |klass| error.is_a?(klass) }
  end
end
