module Webui
  module Users
    class BsRequestsController < WebuiController
      before_action :check_display_user

      REQUEST_METHODS = {
        'all_requests_table'      => :requests,
        'requests_out_table'      => :outgoing_requests,
        'requests_declined_table' => :declined_requests,
        'requests_in_table'       => :incoming_requests,
        'reviews_in_table'        => :involved_reviews
      }

      def index
        parsed_params =
          BsRequest::DataTable::ParamsParser.new(params)
          .parsed_params
          .merge(request_method: request_method)

        requests_query = BsRequest::DataTable::FindForUserQuery.new(@displayed_user, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

        respond_to do |format|
          format.json
        end
      end

      private

      def request_method
        REQUEST_METHODS[params[:dataTableId]] || :requests
      end
    end
  end
end
