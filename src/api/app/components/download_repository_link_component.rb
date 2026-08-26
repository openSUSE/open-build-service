class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :download_area_url

  def initialize(project:, repository:, configuration:)
    super()

    download_url = configuration['download_url']
    return unless download_url

    return unless Backend::Api::Published.published_repository_exist?(project.name, repository.name)

    @download_area_url = "#{download_url}/#{project.name.gsub(':', ':/')}/#{repository.name}"
  end
end
