module Webui
  module Packages
    class BuildReasonController < Webui::WebuiController
      include ScmsyncChecker

      before_action :set_project
      before_action :check_scmsync
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @details = @package.last_build_reason(@repository, @architecture.name, @package_name)
        return if @details.explain.present?

        redirect_back_or_to project_package_repository_binaries_path(package_name: @package, project_name: @project,
                                                                     repository_name: @repository.name),
                            notice: "No build reason found for #{@repository.name}:#{@architecture.name}"
      end
    end
  end
end
