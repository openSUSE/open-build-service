module Webui
  module Packages
    class MainController < WebuiController
      protected

      def set_package
        # Store the package name in case of multibuilds
        @package_name = params[:package_name]
        @package = ::Package.get_by_project_and_name(@project.to_param, params[:package_name],
                                                     use_source: false, follow_project_links: true, follow_multibuild: true)
      rescue APIError
        raise ActiveRecord::RecordNotFound, 'Not Found'
      end

      def set_repository
        repository_name = params[:repository] || params[:repository_name]
        @repository = @project.repositories.find_by(name: repository_name)
        return @repository if @repository

        flash[:error] = "Couldn't find repository '#{repository_name}'."
        redirect_to(project_package_repository_binaries_path(package_name: @package.name, project_name: @project.name, repository_name: repository_name))
      end

      def set_architecture
        @architecture = ::Architecture.archcache[params[:arch]]
        return @architecture if @architecture

        flash[:error] = "Couldn't find architecture '#{params[:arch]}'."
        redirect_to(project_package_repository_binaries_path(package_name: @package.name, project_name: @project.name, repository_name: params[:repository]))
      end
    end
  end
end
