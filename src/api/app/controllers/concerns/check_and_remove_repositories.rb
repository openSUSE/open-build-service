module CheckAndRemoveRepositories
  extend ActiveSupport::Concern

  def check_and_remove_repositories!(repositories, opts)
    result = Project.check_repositories(repositories) unless opts[:force]
    raise Source::Errors::RepoDependency, result[:error] if !opts[:force] && result[:error]

    result = Project.remove_repositories(repositories, opts)
    raise Source::Errors::ChangeProjectNoPermission, result[:error] if !opts[:force] && result[:error]
  end
end
