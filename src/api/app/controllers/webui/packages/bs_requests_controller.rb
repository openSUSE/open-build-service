# frozen_string_literal: true
module Webui
  module Packages
    class BsRequestsController < WebuiController
      before_action :set_project
      before_action :require_package

      def index
        parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForPackageQuery.new(@project, @package, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

        # NOTE: This session is used by requests/show
        session[:request_numbers] = requests_query.requests.map(&:number)

        respond_to do |format|
          format.json
        end
      end
    end
  end
end
