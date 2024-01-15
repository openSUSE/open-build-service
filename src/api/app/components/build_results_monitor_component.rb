class BuildResultsMonitorComponent < ApplicationComponent
  attr_reader :raw_data

  def initialize(raw_data:)
    super

    @raw_data = raw_data
  end

  private

  def package_names
    raw_data.pluck(:package_name).uniq
  end

  def project_name
    raw_data.pluck(:project_name).uniq
  end

  def repository_names
    raw_data.pluck(:repository).uniq
  end

  def results_per_package(package_name)
    raw_data.select { |result| result[:package_name] == package_name }
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
end
