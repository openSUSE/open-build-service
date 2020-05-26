module Webui
  module Requests
    class DeletionsController < WebuiController
      before_action :require_login
      before_action :lockout_spiders
      before_action :set_package, only: [:new]
      before_action :set_project, only: [:new]

      after_action :verify_authorized

      def new
        bs_request_action = BsRequestAction.new(target_package: @package, target_project: @project, type: 'delete')
        @bs_request = BsRequest.new(bs_request_actions: [bs_request_action])
        authorize @bs_request, :create?
      end

      def create
        request = BsRequest.new(bs_request_params)
        authorize request, :create?
        begin
          request.save!
        rescue APIError => e
          flash[:error] = e.message
          redirect_to(controller: :package, action: :show, package: params[:package_name], project: params[:project_name]) && return if @package
          redirect_to(controller: :project, action: :show, project: params[:project_name]) && return
        end
        redirect_to request_show_path(request.number)
      end

      private

      def bs_request_params
        params.require(:bs_request).permit(:description, bs_request_actions_attributes: [:target_project, :target_package, :type])
      end

      def set_package
        return unless params.key?(:package_name)

        @package = Package.find_by(name: params[:package_name])
      end
    end
  end
end
