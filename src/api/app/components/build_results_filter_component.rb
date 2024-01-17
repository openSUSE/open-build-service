class BuildResultsFilterComponent < ApplicationComponent
  attr_reader :package_names, :repository_names, :architecture_names, :status_names, :filter_url, :filters

  def initialize(package_names:, repository_names:, architecture_names:, status_names:, filter_url:, filters:)
    super

    @package_names = package_names
    @repository_names = repository_names
    @architecture_names = architecture_names
    @status_names = status_names
    @filter_url = filter_url
    @filters = filters
  end
end
