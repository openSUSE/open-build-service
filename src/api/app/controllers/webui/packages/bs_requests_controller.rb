module Webui
  module Packages
    class BsRequestsController < Webui::WebuiController
      before_action :set_project
      before_action :require_package

      def index
        if Flipper.enabled?(:request_index, User.session)
          redirect_to project_package_requests_beta_path(@project, @package, action_type: params[:action_type], state: params[:state])
        else
          parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
          requests_query = BsRequest::DataTable::FindForPackageQuery.new(@project, @package, parsed_params)
          @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

          respond_to do |format|
            format.json { render 'webui/shared/bs_requests/index' }
          end
        end
      end
    end
  end
end
