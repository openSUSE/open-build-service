module Webui
  module Packages
    class MainController < WebuiController
      protected

      def set_package
        # Store the package name in case of multibuilds
        @package_name = params[:package_name]
        @package = ::Package.get_by_project_and_name(@project.to_param, params[:package_name],
                                                     use_source: false, follow_project_links: true, follow_multibuild: true)
        @is_link = @package.is_link? || @package.is_local_link?
      rescue APIError
        raise ActiveRecord::RecordNotFound, 'Not Found'
      end

      def set_repository
        @repository = @project.repositories.find_by(name: params[:repository])
        return @repository if @repository

        flash[:error] = "Couldn't find repository '#{params[:repository]}'."
        redirect_to(package_binaries_path(package: @package.name, project: @project.name, repository: params[:repository]))
      end

      def set_architecture
        @architecture = ::Architecture.archcache[params[:arch]]
        return @architecture if @architecture

        flash[:error] = "Couldn't find architecture '#{params[:arch]}'."
        redirect_to(package_binaries_path(package: @package.name, project: @project.name, repository: params[:repository]))
      end
    end
  end
end
