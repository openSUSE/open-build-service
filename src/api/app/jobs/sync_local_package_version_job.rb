class SyncLocalPackageVersionJob < ApplicationJob
  queue_as :quick

  include PackageVersionLabeler

  def perform(project_name, package_name: nil)
    project = Project.find_by_name(project_name)
    distribution_name = project.anitya_distribution_name
    PackageVersionLocal.where(package_id: project.packages.ids).delete_all && return if distribution_name.blank?

    create_package_version_local(project_name: project_name, package_name: package_name)
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def create_package_version_local(project_name:, package_name:)
    info = if package_name
             Backend::Api::Sources::Package.files(project_name, package_name, view: :info, parse: 1)
           else
             Backend::Api::Sources::Project.packages(project_name, view: :info, parse: 1)
           end

    Nokogiri::XML(info).xpath('//sourceinfo[@package]').group_by { |s| s['package'] }.each do |pkg_name, nodes|
      package = Package.find_by_project_and_name(project_name, pkg_name)
      # Prefer service-generated version as set_version modifies it during build.
      version = (nodes.find { |s| s.at('filename')&.content&.start_with?('_service:') } || nodes.first).at('version')&.content
      next unless package && version

      package_version_local = PackageVersionLocal.find_or_create_by(version: version, package: package)
      package_version_local.touch if package_version_local.persisted? # rubocop:disable Rails/SkipsModelValidations
      update_package_version_labels(package_ids: [package.id])
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
