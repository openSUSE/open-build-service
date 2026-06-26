class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :download_area_url

  def initialize(project:, repository:, configuration:)
    super()

    download_url = configuration['download_url']
    return unless download_url

    return unless published_repository?(project: project, repository: repository)

    @download_area_url = "#{download_url}/#{project.to_s.gsub(/:/, ':/')}/#{repository}"
  end

  private

  def published_repository?(project:, repository:)
    Backend::Api::Published.published_repository_exist?(project.to_s, repository.to_s)
  rescue Backend::NotFoundError
    false
  end
end
