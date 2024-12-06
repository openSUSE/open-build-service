module Webui
  module Projects
    class BsRequestsController < WebuiController
      include Webui::RequestsFilter

      before_action :set_project

      def index
        if Flipper.enabled?(:request_index, User.session)
          filter_requests

          @bs_requests = @bs_requests.order('number DESC').page(params[:page])
          @bs_requests = @bs_requests.includes(:bs_request_actions, :comments, :reviews)
          @bs_requests = @bs_requests.includes(:labels) if Flipper.enabled?(:labels, User.session)
        else
          parsed_params = BsRequest::DataTable::ParamsParserWithStateAndType.new(params).parsed_params
          requests_query = BsRequest::DataTable::FindForProjectQuery.new(@project, parsed_params)
          @requests_data_table = BsRequest::DataTable::Table.new(requests_query, params[:draw])

          respond_to do |format|
            format.json { render 'webui/shared/bs_requests/index' }
          end
        end
      end

      private

      def filter_by_involvement(filter_by_involvement)
        target = BsRequest::FindFor::Project.new({ project: @project.name, source_or_target: 'target' }).all
        source = BsRequest::FindFor::Project.new({ project: @project.name, source_or_target: 'source' }).all
        case filter_by_involvement
        when 'all'
          target.or(source)
        when 'incoming'
          target
        when 'outgoing'
          source
        end
      end
    end
  end
end
