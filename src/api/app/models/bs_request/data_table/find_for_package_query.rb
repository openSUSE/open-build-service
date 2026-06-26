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
        BsRequest::FindFor::Query.new(@params.merge(project: @project.name, package: @package.name)).all
      end

      def request_query_without_search
        BsRequest::FindFor::Query.new(@params.except(:search).merge(project: @project.name, package: @package.name)).all
      end
    end
  end
end
