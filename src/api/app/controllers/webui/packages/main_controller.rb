module Webui
  module Packages
    class MainController < WebuiController
      protected

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

        repository_name = params[:repository] || params[:repository_name]
        redirect_to(project_package_repository_binaries_path(package_name: @package.name,
                                                             project_name: @project.name,
                                                             repository_name: repository_name))
      end
    end
  end
end
