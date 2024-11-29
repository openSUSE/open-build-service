module Webui
  module Users
    class BsRequestsController < WebuiController
      before_action :require_login
      before_action :set_user

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_out_table' => :outgoing_requests,
        'requests_declined_table' => :declined_requests,
        'requests_in_table' => :incoming_requests,
        'reviews_in_table' => :involved_reviews
      }.freeze

      def index
        if Flipper.enabled?(:request_index, User.session)
          redirect_to requests_path(involvement: params[:involvement], state: params[:state])
        else
          parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
          requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@user_or_group, request_method, parsed_params)
          @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

          respond_to do |format|
            format.json { render 'webui/shared/bs_requests/index' }
          end
        end
      end

      private

      def set_user
        @user_or_group = User.session
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]] || :requests
      end
    end
  end
end
