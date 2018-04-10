# frozen_string_literal: true
class BsRequest
  module DataTable
    class FindForProjectQuery
      def initialize(project, params)
        @project = project
        @params = params
      end

      def requests
        @requests ||=
          request_query
          .offset(@params[:offset])
          .limit(@params[:limit])
          .reorder(@params[:sort])
          .includes(:bs_request_actions)
      end

      def records_total
        request_query_without_search.count
      end

      def count_requests
        request_query.count
      end

      private

      def request_query
        BsRequest.find_for(
          @params.merge(project: @project.name)
        )
      end

      def request_query_without_search
        BsRequest.find_for(
          @params.except(:search).merge(project: @project.name)
        )
      end
    end
  end
end
