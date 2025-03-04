module Webui
  module Groups
    class BsRequestsController < WebuiController
      before_action :set_group
      before_action :redirect_legacy
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
          end
          format.json do
            parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
            requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@group, request_method, parsed_params)
            @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

            render 'webui/shared/bs_requests/index'
          end
        end
      end

      private

      def set_group
        @group = Group.find_by_title!(params[:group_title])
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]]
      end

      def set_bs_request
        return unless Flipper.enabled?(:request_index, User.possibly_nobody)

        @bs_requests = @group.bs_requests
      end

      def filter_involvement
        @selected_filter['involvement'] = params[:involvement] if params[:involvement]&.compact_blank.present?

        bs_requests_filters = []

        if @selected_filter['involvement'].include?('incoming')
          bs_requests_filters << @bs_requests.where(bs_request_actions: { target_project_id: @group.relationships.projects.maintainers.pluck(:project_id) })
          bs_requests_filters << @bs_requests.where(bs_request_actions: { target_package_id: @group.relationships.packages.maintainers.pluck(:package_id) })
        end

        if @selected_filter['involvement'].include?('outgoing')
          bs_requests_filters << @bs_requests.where(bs_request_actions: { source_project_id: @group.relationships.projects.maintainers.pluck(:project_id) })
          bs_requests_filters << @bs_requests.where(bs_request_actions: { source_package_id: @group.relationships.packages.maintainers.pluck(:package_id) })
        end

        if @selected_filter['involvement'].include?('review')
          bs_requests_filters << @bs_requests.where(reviews: { group_id: @group.id })
          bs_requests_filters << @bs_requests.where(reviews: { project_id: @group.relationships.projects.maintainers.pluck(:project_id) })
          bs_requests_filters << @bs_requests.where(reviews: { package_id: @group.relationships.packages.maintainers.pluck(:package_id) })
        end

        @bs_requests = @bs_requests.merge(bs_requests_filters.inject(:or)) if bs_requests_filters.length.positive?
      end

      def redirect_legacy
        redirect_to(group_path(@group)) unless Flipper.enabled?(:request_index, User.possibly_nobody) || request.format.json?
      end
    end
  end
end
