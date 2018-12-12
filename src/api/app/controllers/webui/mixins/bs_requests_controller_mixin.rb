module Webui
  module Mixins
    module BsRequestsControllerMixin
      def index
        parsed_params = BsRequest::DataTable::ParamsParser.new(params).parsed_params
        requests_query = BsRequest::DataTable::FindForUserOrGroupQuery.new(@user_or_group, request_method, parsed_params)
        @requests_data_table = BsRequest::DataTable::Table.new(requests_query, parsed_params[:draw])

        namespace = params[:switch_to_webui2] ? 'webui2' : 'webui'
        respond_to do |format|
          format.json { render "#{namespace}/shared/bs_requests/index" }
        end
      end
    end
  end
end
