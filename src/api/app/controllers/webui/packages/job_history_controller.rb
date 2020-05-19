module Webui
  module Packages
    class JobHistoryController < Packages::MainController
      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @jobshistory = @package.jobhistory(repository_name: @repository.name, arch_name: @architecture.name, package_name: @package_name, project_name: @project.name)
      end
    end
  end
end
