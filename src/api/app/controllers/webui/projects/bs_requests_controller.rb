module Webui
  module Projects
    class BsRequestsController < WebuiController
      include Webui::RequestsFilter

      before_action :set_project
      before_action :redirect_legacy
      before_action :set_bs_requests

      def index
        respond_to do |format|
          format.html do
            filter_requests
            @bs_requests = @bs_requests.page(params[:page]).includes(:bs_request_actions)
            @bs_requests = @bs_requests.includes(labels: :label_template)
          end
          format.json do
            parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
            requests_query = BsRequest::DataTable::FindForProjectQuery.new(@project, parsed_params)
            @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

            render 'webui/shared/bs_requests/index'
          end
        end
      end

      private

      def set_bs_requests
        return unless Flipper.enabled?(:request_index, User.session)

        @bs_requests = @project.bs_requests
      end

      def incoming_query
        @bs_requests.where(bs_request_actions: { target_project_id: @project.id })
      end

      def outgoing_query
        @bs_requests.where(bs_request_actions: { source_project_id: @project.id })
      end

      def review_query
        @bs_requests.where(reviews: { project_id: @project.id })
      end

      def redirect_legacy
        redirect_to(project_requests_path(@project)) unless Flipper.enabled?(:request_index, User.session) || request.format.json?
      end
    end
  end
end
