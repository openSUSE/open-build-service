class FetchLocalPackageVersionJob < ApplicationJob
  queue_as :quick

  def perform(project_name, package_name: nil)
    info = if package_name
             Backend::Api::Sources::Package.files(project_name, package_name, view: :info, parse: 1)
           else
             begin
               Backend::Api::Sources::Project.packages(project_name, view: :info, parse: 1)
             rescue Backend::NotFoundError
               logger.info("FetchLocalPackageVersionJob: #{project_name} has no packages in the Backend")
               nil
             end
           end

    create_local_version_from_backend_output(info) if info
  end

  def create_local_version_from_backend_output(info)
    Nokogiri::XML(info).xpath('//sourceinfo[@package]').each do |sourceinfo|
      next unless (package = Package.find_by_project_and_name(project_name, sourceinfo['package']))
      next unless (version = sourceinfo.at('version')&.content)

      PackageVersionLocal.find_or_create_by(version: version, package: package)
    end
  end
end
