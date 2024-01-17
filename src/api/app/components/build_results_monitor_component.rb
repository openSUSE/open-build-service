class BuildResultsMonitorComponent < ApplicationComponent
  attr_reader :raw_data, :filter_url, :filters

  def initialize(raw_data:, filter_url:, filters:)
    super

    @raw_data = raw_data
    @filter_url = filter_url
    @filters = filters
    @filtered_data = filtered_data(raw_data)
  end

  private

  def package_names
    raw_data.pluck(:package_name).uniq
  end

  def filtered_package_names
    @filtered_data.pluck(:package_name).uniq
  end

  def project_name
    raw_data.pluck(:project_name).uniq
  end

  def repository_names
    raw_data.pluck(:repository).uniq
  end

  def filtered_repository_names
    @filtered_data.pluck(:repository).uniq
  end

  def architecture_names
    raw_data.pluck(:architecture).uniq
  end

  def status_names
    raw_data.pluck(:status).uniq
  end

  def results_per_package(package_name)
    return {} if @filtered_data.blank?

    @filtered_data.select { |result| result[:package_name] == package_name }
  end

  def results_count_per_package_and_category(package)
    categories_count = Hash.new(0)
    Buildresult::BUILD_STATUS_CATEGORIES.each do |category|
      current_count = results_per_package(package).count { |result| Buildresult::BUILD_STATUS_CATEGORIES_MAP[result[:status]] == category }
      categories_count[category] = current_count if current_count.positive?
    end
    categories_count
  end

  def results_per_package_and_repository(package, repository)
    results_per_package(package).select { |result| result[:repository] == repository }
  end

  def live_build_log_url(status, project, package, repository, architecture)
    return if ['unresolvable', 'blocked', 'excluded', 'scheduled'].include?(status)

    package_live_build_log_path(project: project,
                                package: package,
                                repository: repository,
                                arch: architecture)
  end

  def repository_status(result)
    return 'Outdated' unless result[:is_repository_in_db]

    result[:repository_status].humanize
  end

  def show
    'show' if filtered_package_names.count == 1
  end

  def filtered_data(data)
    data = filter_data_by_multiple_values(data, filters_by_type('package_'), 'package_', :package_name)
    data = filter_data_by_multiple_values(data, filters_by_type('repo_'), 'repo_', :repository)
    data = filter_data_by_multiple_values(data, filters_by_type('arch_'), 'arch_', :architecture)
    filter_data_by_multiple_values(data, filters_by_type('status_'), 'status_', :status)
  end

  def filters_by_type(prefix)
    filters.select { |filter| filter.starts_with?(prefix) }
  end

  def filter_data_by_multiple_values(data, filters, prefix, key_name)
    return data if filters.blank?

    data.select { |result| filters.include?("#{prefix}#{result[key_name]}") }
  end
end
