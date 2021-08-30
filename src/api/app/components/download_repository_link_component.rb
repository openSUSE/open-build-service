class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :published_repository_exist, :download_area_url

  def initialize(project:, repository:, configuration:)
    super

    @published_repository_exist = false
    download_url = configuration['download_url']
    return unless download_url

    @published_repository_exist = Backend::Api::Published.published_repository_exist?(project.to_s, repository.to_s)
    @download_area_url = "#{download_url}/#{project.to_s.gsub(/:/, ':/')}/#{repository}"
  end
end
