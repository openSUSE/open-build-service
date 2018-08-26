module Webui
  module Projects
    class BsRequestsController < WebuiController
      before_action :set_project

      def index
        parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForProjectQuery.new(@project, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

        # NOTE: This session is used by requests/show
        session[:request_numbers] = requests_query.requests.map(&:number)

        respond_to do |format|
          format.json
        end
        switch_to_webui2
      end
    end
  end
end
