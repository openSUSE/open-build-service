class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :download_area_url

  def initialize(project:, repository:, configuration:)
    super()

    download_url = configuration['download_url']
    @download_area_url = if download_url && published_repository?(project.to_s, repository.to_s)
      "#{download_url}/#{project.to_s.gsub(/:/, ':/')}/#{repository}"
    end
  end

  private

  def published_repository?(project_name, repository_name)
    Backend::Api::Published.published_repository_exist?(project_name, repository_name)
  rescue Backend::NotFoundError
    false
  end
end
