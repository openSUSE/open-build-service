module Webui
  module Packages
    class BsRequestsController < WebuiController
      include Webui::RequestsFilter

      before_action :set_project
      before_action :set_package
      before_action :redirect_legacy
      before_action :set_bs_requests

      def index
        respond_to do |format|
          format.html do
            filter_requests
            @bs_requests = @bs_requests.page(params[:page]).includes(:bs_request_actions)
            @bs_requests = @bs_requests.includes(labels: :label_template) if Flipper.enabled?(:labels, User.session)
            @url = packages_requests_path(@project, @package)
          end
          format.json do
            parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
            requests_query = BsRequest::DataTable::FindForPackageQuery.new(@project, @package, parsed_params)
            @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

            render 'webui/shared/bs_requests/index'
          end
        end
      end

      private

      def set_bs_requests
        return unless Flipper.enabled?(:request_index, User.session)

        @bs_requests = @package.bs_requests
      end

      def incoming_query
        @bs_requests.where(bs_request_actions: { target_package_id: @package.id })
      end

      def outgoing_query
        @bs_requests.where(bs_request_actions: { source_package_id: @package.id })
      end

      def review_query
        @bs_requests.where(reviews: { package_id: @package.id })
      end

      def redirect_legacy
        redirect_to(package_requests_path(@project, @package)) unless Flipper.enabled?(:request_index, User.session) || request.format.json?
      end
    end
  end
end
