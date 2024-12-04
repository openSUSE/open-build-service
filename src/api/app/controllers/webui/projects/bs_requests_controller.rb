module Webui
  module Projects
    class BsRequestsController < WebuiController
      include Webui::RequestsFilter

      before_action :set_project

      def index
        if Flipper.enabled?(:request_index, User.session)
          set_filter_involvement
          set_filter_state
          set_filter_action_type
          set_filter_creators

          filter_requests
          set_selected_filter

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

      def set_selected_filter
        @selected_filter = { involvement: @filter_involvement, action_type: @filter_action_type, search_text: params[:requests_search_text],
                             state: @filter_state, creators: @filter_creators }
      end

      def filter_by_involvement(filter_by_involvement)
        target = BsRequest.with_actions.where(bs_request_actions: { target_project: @project.name })
        source = BsRequest.with_actions.where(bs_request_actions: { source_project: @project.name })
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
