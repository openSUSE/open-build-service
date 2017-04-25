module Webui
  module Users
    class BsRequestsController < WebuiController
      before_action :check_display_user

      def index
        parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForUserQuery.new(@displayed_user, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

        respond_to do |format|
          format.json
        end
      end
    end
  end
end
