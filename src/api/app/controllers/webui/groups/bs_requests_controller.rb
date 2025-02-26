module Webui
  module Groups
    class BsRequestsController < WebuiController
      before_action :set_group
      before_action :require_login
      before_action :set_bs_request

      include Webui::RequestsFilter

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_in_table' => :incoming_requests,
        'reviews_in_table' => :involved_reviews
      }.freeze

      def index
        respond_to do |format|
          format.html do
            filter_requests

            @bs_requests = @bs_requests.order('number DESC').page(params[:page])
            @bs_requests = @bs_requests.includes(:bs_request_actions, :comments, :reviews)
            @bs_requests = @bs_requests.includes(:labels) if Flipper.enabled?(:labels, User.session)
          end
          format.json do
            parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
            requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@user_or_group, request_method, parsed_params)
            @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

            render 'webui/shared/bs_requests/index'
          end
        end
      end

      private

      def set_group
        @user_or_group = Group.find_by_title!(params[:group_title])
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]]
      end

      def set_bs_request
        @bs_requests = @user_or_group.requests
      end

      def filter_involvement
        return if params[:involvement]&.compact_blank.blank?

        @selected_filter['involvement'] = params[:involvement]

        @bs_requests = case
                       when @selected_filter['involvement'].include?('incoming')
                         BsRequest::FindFor::Query.new({ group: @user_or_group.title, roles: [:maintainer] }, @bs_requests).all
                       when @selected_filter['involvement'].include?('review')
                         BsRequest::FindFor::Query.new({ group: @user_or_group.title, roles: [:reviewer] }, @bs_requests).all
                       end
      end
    end
  end
end
