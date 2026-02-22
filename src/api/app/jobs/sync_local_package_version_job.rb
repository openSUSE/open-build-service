class SyncLocalPackageVersionJob < ApplicationJob
  queue_as :slow_user

  def perform(project_name, package_name: nil)
    project = Project.find_by_name(project_name)
    distribution_name = project.anitya_distribution_name
    PackageVersionLocal.where(package_id: project.packages.ids).delete_all && return if distribution_name.blank?

    create_package_version_local(project_name: project_name, package_name: package_name)
  end

  def create_package_version_local(project_name:, package_name:)
    info = if package_name
             Backend::Api::Sources::Package.files(project_name, package_name, view: :info, parse: 1)
           else
             Backend::Api::Sources::Project.packages(project_name, view: :info, parse: 1)
           end

    Nokogiri::XML(info).xpath('//sourceinfo[@package]').each do |sourceinfo|
      next unless (package = Package.find_by_project_and_name(project_name, sourceinfo['package']))
      next unless (version = sourceinfo.at('version')&.content)

      package_version_local = PackageVersionLocal.find_or_create_by(version: version, package: package)
      package_version_local.touch if package_version_local.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
