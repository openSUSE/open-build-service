module Webui
  module Projects
    class BsRequestsController < WebuiController
      before_action :set_project

      def index
        parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForProjectQuery.new(
          @project, types, states, parsed_params
        )
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

        respond_to do |format|
          format.json
        end
      end

      private

      def types
        [params[:type]] if params[:type].present?
      end

      def states
        if params[:state] == 'new or review'
          ['new', 'review']
        elsif params[:state].present?
          [params[:state]]
        end
      end
    end
  end
end
