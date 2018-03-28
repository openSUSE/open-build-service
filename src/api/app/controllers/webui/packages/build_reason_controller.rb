module Webui
  module Packages
    class BuildReasonController < WebuiController
      before_action :set_project
      before_action :require_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @details = @package.last_build_reason(@project.name, @repository, @architecture.name)

        return if @details.explain

        redirect_back(fallback_location: package_binaries_path(package: @package, project: @project, repository: @repository.name),
                      notice: "No build reason found for #{@repository.name}:#{@architecture.name}")
      end

      private

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
