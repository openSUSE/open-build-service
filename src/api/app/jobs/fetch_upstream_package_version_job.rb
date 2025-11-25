# Job to fetch upstream versions for all packages
class FetchUpstreamPackageVersionJob < ApplicationJob
  queue_as :quick

  def perform(project_name: nil)
    if project_name.present?
      create_for_project(project_name: project_name)
    else
      create_for_all_projects_with_anitya_distribtion_name
    end
  end

  private

  def create_for_project(project_name:)
    project = Project.find_by_name(project_name)
    return if project.blank?

    distribution_name = project.anitya_distribution_name
    return if distribution_name.blank?

    project.packages.each do |package|
      create_upstream_package_versions(package_name: package.name, distribution_name: distribution_name, package_ids: [package.id])
    end
  end

  def create_for_all_projects_with_anitya_distribtion_name
    package_and_distro_name_grouped_on_package_ids = Project.where.not(anitya_distribution_name: [nil, '']).joins(:packages).select('projects.anitya_distribution_name AS anitya_distribution_name',
                                                                                                                                    'packages.name AS package_name',
                                                                                                                                    'packages.id AS project_package_id').group_by do |s|
      [s.anitya_distribution_name, s.package_name]
    end

    package_and_distro_name_grouped_on_package_ids.each do |(distribution_name, package_name), projects|
      package_ids = projects.map(&:project_package_id)
      create_upstream_package_versions(package_name:, distribution_name:, package_ids:)
    end
  end

  def create_upstream_package_versions(package_name:, distribution_name:, package_ids:)
    response = fetch_upstream_package_info(package_name: package_name, distribution_name: distribution_name)

    # When we get empty result, we can’t rely on the past information we stored in the database anymore
    PackageVersionUpstream.where(package_id: package_ids).delete_all && return if response&.dig('total_items')&.zero?

    upstream_version = extract_version(response)
    return if upstream_version.blank?

    package_ids.each do |package_id|
      package_version_upstream = PackageVersionUpstream.find_or_create_by(version: upstream_version, package_id: package_id)
      package_version_upstream.touch if package_version_upstream.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def fetch_upstream_package_info(package_name:, distribution_name:)
    url = URI.parse("https://release-monitoring.org/api/v2/packages/?name=#{package_name}&distribution=#{distribution_name}")
    response = Net::HTTP.get_response(url)
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  end

  def extract_version(response)
    return if response.nil?

    response.dig('items', 0, 'stable_version')
  end
end
