class BsRequest
  module DataTable
    class FindForPackageQuery
      def initialize(project, package, params)
        @project = project
        @package = package
        @params = params
      end

      def requests
        @requests ||=
          request_query
          .offset(@params[:offset])
          .limit(@params[:limit])
          .reorder(@params[:sort_column] => @params[:sort_direction])
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
        BsRequest.collection(
          @params.merge(project: @project.name, package: @package.name)
        )
      end

      def request_query_without_search
        BsRequest.collection(
          @params.except(:search).merge(project: @project.name, package: @package.name)
        )
      end
    end
  end
end
