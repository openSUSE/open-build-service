module Webui
  module Packages
    class JobHistoryController < WebuiController
      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @jobshistory = @package.jobhistory_list(@project, @repository.name, @architecture.name)
      end

      private

      def set_package
        @package = ::Package.get_by_project_and_name(@project.to_param, params[:package_name],
                                                     use_source: false, follow_project_links: true, follow_multibuild: true)
        @is_link = @package.is_link? || @package.is_local_link?
      rescue APIException
        flash[:error] = "Package \"#{params[:package_name]}\" not found in project \"#{params[:project]}\""
        redirect_to project_show_path(project: @project, nextstatus: 404)
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
