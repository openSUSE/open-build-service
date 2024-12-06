module Webui
  module Users
    class BsRequestsController < WebuiController
      before_action :require_login
      before_action :set_user

      include Webui::RequestsFilter

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_out_table' => :outgoing_requests,
        'requests_declined_table' => :declined_requests,
        'requests_in_table' => :incoming_requests,
        'reviews_in_table' => :involved_reviews
      }.freeze

      def index
        if Flipper.enabled?(:request_index, User.session)
          filter_requests

          # TODO: Temporarily disable list of creators due to performance issues
          # @bs_requests_creators = @bs_requests.distinct.pluck(:creator)
          @bs_requests = @bs_requests.order('number DESC').page(params[:page])
          @bs_requests = @bs_requests.includes(:bs_request_actions, :comments, :reviews)
          @bs_requests = @bs_requests.includes(:labels) if Flipper.enabled?(:labels, User.session)
        else
          index_legacy
        end
      end

      private

      def filter_by_direction(direction)
        case direction
        when 'all'
          User.session.requests
        when 'incoming'
          User.session.incoming_requests
        when 'outgoing'
          User.session.outgoing_requests
        end
      end

      def set_user
        @user_or_group = User.session
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]] || :requests
      end

      # TODO: Remove this old index action when request_index feature is rolled-over
      def index_legacy
        parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@user_or_group, request_method, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

        respond_to do |format|
          format.json { render 'webui/shared/bs_requests/index' }
        end
      end
    end
  end
end
