class ProjectDoProjectCopyJob < ApplicationJob
  queue_as :quick

  attr_accessor :project, :params

  def perform(project_id, params)
    project = Project.find(project_id)

    User.find_by!(login: params[:user]).run_as do
      # copy entire project in the backend
      begin
        Backend::Api::Sources::Project.copy(project.name, params)
      rescue Backend::Error => e
        logger.debug "copy failed: #{e.summary}"
        # we need to check results of backend in any case (also timeout error eg)
      end

      # restore all package meta data objects in DB
      backend_pkgs = Xmlhash.parse(Backend::Api::Search.packages_for_project(project.name))
      backend_pkgs.elements('package') do |package|
        pkg_name = package['name']
        pkg = project.packages.where(name: pkg_name).first_or_initialize
        pkg.update_from_xml(Xmlhash.parse(Backend::Api::Sources::Package.meta(project.name, pkg_name)))
        pkg.save!
      end
      project.all_sources_changed
    end
  end
end
