# Job to fetch upstream versions for all packages
class FetchUpstreamPackageVersionJob < ApplicationJob
  queue_as :quick

  def perform(project_name: nil)
    attribute_type_anitya_distribution = AttribType.find_by_namespace_and_name('OBS', 'AnityaDistribution')
    return if attribute_type_anitya_distribution.blank?

    if project_name.present?
      create_for_project(project_name: project_name,
                         attribute_type_anitya_distribution: attribute_type_anitya_distribution)
    else
      attribs = attribute_type_anitya_distribution.attribs
      return if attribs.blank?

      create_for_all_projects_with_attribute_set(attribs: attribs)
    end
  end

  private

  def create_for_project(project_name:, attribute_type_anitya_distribution:)
    project = Project.find_by_name(project_name)
    return if project.blank?

    attribs = project.attribs.find_by_attrib_type_id(attribute_type_anitya_distribution.id)
    return if attribs.blank?

    distribution_name = attribs.values.first&.value

    project.packages.each do |package|
      create_upstream_package_versions(package_name: package.name, distribution_name: distribution_name, package_ids: [package.id])
    end
  end

  def create_for_all_projects_with_attribute_set(attribs:)
    package_and_distro_name_grouped_on_package_ids = attribs.joins(:values, project: [:packages]).select('attrib_values.value AS attrib_value', 'packages.name AS package_name',
                                                                                                         'packages.id AS project_package_id').group_by do |s|
      [s.attrib_value, s.package_name]
    end

    package_and_distro_name_grouped_on_package_ids.each do |(distribution_name, package_name), attributes|
      package_ids = attributes.map(&:project_package_id)
      create_upstream_package_versions(package_name:, distribution_name:, package_ids:)
    end
  end

  def create_upstream_package_versions(package_name:, distribution_name:, package_ids:)
    response = fetch_upstream_package_info(package_name: package_name, distribution_name: distribution_name)
    upstream_version = extract_version(response)
    return if upstream_version.blank?

    package_ids.each do |package_id|
      PackageVersionUpstream.find_or_create_by(version: upstream_version, package_id: package_id)
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
