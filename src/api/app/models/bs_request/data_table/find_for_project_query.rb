class BsRequest
  module DataTable
    class FindForProjectQuery
      def initialize(project, types, states, params)
        @project = project
        @types = types
        @states = states
        @params = params
      end

      def requests
        @requests ||= BsRequest.list(
          @params.merge(project: @project.name, types: @types, states: @states)
        )
      end

      # TODO: This should show the number of requests without the search applied
      def records_total
        requests.count
      end

      # TODO: This should show the number of requests with the search applied
      def count_requests
        requests.count
      end
    end
  end
end
