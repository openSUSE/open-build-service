class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :project_repository_download_url

  def initialize(project:, repository:)
    super()

    return unless Backend::Api::Published.published_repository_exist?(project.name, repository.name)

    @project_repository_download_url = "#{::Configuration.download_url}/#{project.name.gsub(':', ':/')}/#{repository.name}"
  end
end
