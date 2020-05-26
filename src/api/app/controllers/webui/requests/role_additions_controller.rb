module Webui
  module Requests
    class RoleAdditionsController < Webui::RequestController
      before_action :require_login
      before_action :set_package
      before_action :set_project

      after_action :verify_authorized

      def new
        bs_request_action = BsRequestAction.new(role: 'maintainer', target_package: @package, target_project: @project, type: 'add_role')
        @bs_request = BsRequest.new(bs_request_actions: [bs_request_action])
        authorize @bs_request, :create?
      end

      private

      def bs_request_params
        params.require(:bs_request).permit(:description, bs_request_actions_attributes: [:group_name, :person_name, :role, :target_project, :target_package, :type])
      end
    end
  end
end
