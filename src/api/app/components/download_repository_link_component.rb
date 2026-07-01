class DownloadRepositoryLinkComponent < ApplicationComponent
  attr_reader :download_area_url

  def initialize(project:, repository:, configuration:)
    super()

    @download_area_url = get_published_url(project.name, repository.name)
  end

  private

  def get_published_url(project_name, repository_name)
    xml_data = Backend::Api::Published.download_url_for_repository(project_name, repository_name)
    return nil if xml_data.blank?

    xml = Xmlhash.parse(xml_data)
    url = xml.elements('url').last&.to_s
    url.presence
  rescue Backend::NotFoundError, Backend::Error
    nil
  end
end
