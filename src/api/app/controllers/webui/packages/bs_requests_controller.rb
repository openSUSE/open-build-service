module Webui
  module Packages
    class BsRequestsController < Packages::MainController
      before_action :set_project
      before_action :require_package

      def index
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
