module Webui
  module Groups
    class BsRequestsController < WebuiController
      before_action :set_group

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_in_table' => :incoming_requests,
        'reviews_in_table' => :involved_reviews
      }.freeze

      def index
        parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@user_or_group, request_method, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

        respond_to do |format|
          format.json { render 'webui/shared/bs_requests/index' }
        end
      end

      private

      def set_group
        @user_or_group = Group.find_by_title!(params[:group_title])
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]]
      end
    end
  end
end
