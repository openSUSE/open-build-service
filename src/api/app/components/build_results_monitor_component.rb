class BuildResultsMonitorComponent < ApplicationComponent
  attr_reader :raw_data, :filter_url, :filters

  def initialize(raw_data:, filter_url:, filters:)
    super

    @raw_data = raw_data
    @filter_url = filter_url
    @filters = default_filters(filters)
    @filtered_data = filtered_data(raw_data)
  end

  private

  def default_filters(filters)
    return filters if filters.any? { it.starts_with?('status_') }

    filters.concat(Buildresult.default_status_filter_values.map { it.prepend('status_') })
  end

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

  def filtered_architecture_names
    @filtered_data.pluck(:architecture).uniq
  end

  def status_names
    Buildresult.avail_status_values
  end

  def results_per_package(package_name)
    return {} if @filtered_data.blank?

    @filtered_data.select { |result| result[:package_name] == package_name }
  end

  def results_count_per_package_and_category(package)
    categories_count = Hash.new(0)
    Buildresult::STATUS_CATEGORIES.each do |category|
      current_count = results_per_package(package).count { |result| Buildresult::STATUS_CATEGORIES_MAP[result[:status]] == category }
      categories_count[category] = current_count if current_count.positive?
    end
    categories_count
  end

  def results_per_package_and_repository(package, repository)
    results_per_package(package).select { |result| result[:repository] == repository }
  end

  def results_per_package_repository_and_architecture(package, repository, architecture)
    results_per_package_and_repository(package, repository).select { |result| result[:architecture] == architecture }
  end

  def show
    'show' if filtered_package_names.count == 1
  end

  def filtered_data(data)
    data = filter_data_by_multiple_values(data, 'package_', :package_name)
    data = filter_data_by_multiple_values(data, 'repo_', :repository)
    data = filter_data_by_multiple_values(data, 'arch_', :architecture)
    filter_data_by_multiple_values(data, 'status_', :status)
  end

  def filters_by_type(prefix)
    filters.select { |filter| filter.starts_with?(prefix) }
  end

  def filter_data_by_multiple_values(data, prefix, key_name)
    filters = filters_by_type(prefix)
    return data if filters.blank?

    data.select { |result| filters.include?("#{prefix}#{result[key_name]}") }
  end
end
