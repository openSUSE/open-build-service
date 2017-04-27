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
        raise ArgumentError unless valid_request_methods.include?(params[:request_method])

        @user.send(params[:request_method], search)
      end

      def valid_request_methods
        Webui::Users::BsRequestsController::REQUEST_METHODS.values
      end
    end
  end
end
