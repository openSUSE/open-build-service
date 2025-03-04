module Webui
  module Packages
    class BsRequestsController < Webui::WebuiController
      include Webui::RequestsFilter

      before_action :set_project
      before_action :require_package
      before_action :redirect_legacy
      before_action :set_bs_requests

      def index
        if Flipper.enabled?(:request_index, User.session)
          # FIXME: Once we roll out filter_requests should become a before_action
          filter_requests
          @bs_requests = @bs_requests.order('number DESC').page(params[:page])

          @url = packages_requests_path(@project, @package)
        else
          parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
          requests_query = BsRequest::DataTable::FindForPackageQuery.new(@project, @package, parsed_params)
          @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

          respond_to do |format|
            format.json { render 'webui/shared/bs_requests/index' }
          end
        end
      end

      private

      def set_bs_requests
        return unless Flipper.enabled?(:request_index, User.session)

        @bs_requests = @package.bs_requests
      end

      def filter_involvement
        @selected_filter['involvement'] = params[:involvement] if params[:involvement]&.compact_blank.present?
        bs_requests_filters = []

        if @selected_filter['involvement'].include?('incoming')
          bs_requests_filters << @bs_requests.where(bs_request_actions: { target_package_id: @package.id })
        end

        if @selected_filter['involvement'].include?('outgoing')
          bs_requests_filters << @bs_requests.where(bs_request_actions: { source_package_id: @package.id })
        end

        if @selected_filter['involvement'].include?('review')
          bs_requests_filters << @bs_requests.where(reviews: { package_id: @package.id })
        end

        @bs_requests = @bs_requests.merge(bs_requests_filters.inject(:or)) if bs_requests_filters.length.positive?
      end

      def redirect_legacy
        redirect_to(package_requests_path(@project, @package)) unless Flipper.enabled?(:request_index, User.session) || request.format.json?
      end
    end
  end
end
