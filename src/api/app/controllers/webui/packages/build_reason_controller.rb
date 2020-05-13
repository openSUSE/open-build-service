module Webui
  module Packages
    class BuildReasonController < Packages::MainController
      before_action :set_project
      before_action :set_package
      before_action :set_repository
      before_action :set_architecture

      def index
        @details = @package.last_build_reason(@repository, @architecture.name, @package_name)
        return if @details.explain.present?

        redirect_back(fallback_location: package_binaries_path(package: @package, project: @project, repository: @repository.name),
                      notice: "No build reason found for #{@repository.name}:#{@architecture.name}")
      end
    end
  end
end
