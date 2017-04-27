class BsRequest
  module DataTable
    class FindForUserQuery
      attr_reader :user, :params

      def initialize(user, params)
        @user = user
        @params = params
      end

      def requests
        @requests ||=
          requests_query(params[:search])
          .offset(params[:offset])
          .limit(params[:limit])
          .reorder(params[:sort_column] => params[:sort_direction])
          .includes(:bs_request_actions)
      end

      def records_total
        requests_query.count
      end

      def count_requests
        requests_query(params[:search]).count
      end

      private

      def requests_query(search = nil)
        # This check is included for security reasons
        raise ArgumentError unless ParamsParser::REQUEST_METHODS.values.include?(params[:request_method])

        @user.send(params[:request_method], search)
      end
    end
  end
end
