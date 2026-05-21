module Webui
  module Packages
    class JobHistoryController < Webui::WebuiController
      include ScmsyncChecker

      before_action :set_project
      before_action :check_scmsync
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @is_link = @package.link? || @package.local_link?
        @jobshistory = @package.jobhistory(repository_name: @repository.name, arch_name: @architecture.name, package_name: @package_name, project_name: @project.name)
      end
    end
  end
end
