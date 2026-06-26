class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :download_area_url

  def initialize(project:, repository:, configuration:)
    super()

    download_url = configuration['download_url']
    return unless download_url

    @download_area_url = published_repository_url(project: project, repository: repository)
  end

  private

  def published_repository_url(project:, repository:)
    xml = Xmlhash.parse(Backend::Api::Published.download_url_for_repository(project.to_s, repository.to_s))
    xml.elements('url').last.to_s.presence
  rescue Backend::NotFoundError
    nil
  end
end
