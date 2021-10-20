module Webui
  module Requests
    class DevelProjectChangesController < Webui::RequestController
      before_action :require_login
      before_action :set_project
      before_action :set_package
      before_action :check_devel_package

      def new
        bs_request_action = BsRequestAction.new(target_package: @package, target_project: @project, source_package: @package, type: 'change_devel')
        @bs_request = BsRequest.new(bs_request_actions: [bs_request_action])
        authorize @bs_request, :create?
      end

      private

      def bs_request_params
        params.require(:bs_request).permit(:description, bs_request_actions_attributes: [:target_project, :target_package, :source_project, :source_package, :type])
      end

      def check_devel_package
        return if @package.develpackage

        flash[:error] = "Package #{elide(@package.name)} doesn't have a devel project"
        redirect_to package_show_path(project: @project, package: @package)
      end
    end
  end
end
