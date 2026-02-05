class FetchLocalPackageVersionJob < ApplicationJob
  queue_as :quick

  def perform(project_name, package_name: nil)
    project = Project.find_by_name(project_name)
    distribution_name = project.anitya_distribution_name

    if distribution_name.blank?
      delete_package_version_local(project.packages.ids)

      return
    end

    info = if package_name
             Backend::Api::Sources::Package.files(project_name, package_name, view: :info, parse: 1)
           else
             Backend::Api::Sources::Project.packages(project_name, view: :info, parse: 1)
           end
    create_package_version_local(info: info, project_name: project_name)
  end

  def delete_package_version_local(package_ids)
    PackageVersionLocal.where(package_id: package_ids).delete_all
  end

  def create_package_version_local(info:, project_name:)
    Nokogiri::XML(info).xpath('//sourceinfo[@package]').each do |sourceinfo|
      next unless (package = Package.find_by_project_and_name(project_name, sourceinfo['package']))
      next unless (version = sourceinfo.at('version')&.content)

      package_version_local = PackageVersionLocal.find_or_create_by(version: version, package: package)
      package_version_local.touch if package_version_local.persisted? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
