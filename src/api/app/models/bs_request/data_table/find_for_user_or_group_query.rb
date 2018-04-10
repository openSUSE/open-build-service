# frozen_string_literal: true
class BsRequest
  module DataTable
    class FindForUserOrGroupQuery
      attr_reader :user, :params

      def initialize(user_or_group, request_method, params)
        @user_or_group = user_or_group
        @request_method = request_method
        @params = params
      end

      def requests
        @requests ||=
          requests_query(@params[:search])
          .offset(@params[:offset])
          .limit(@params[:limit])
          .reorder(@params[:sort])
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
        raise ArgumentError unless valid_request_methods.include?(@request_method)

        @user_or_group.send(@request_method, search)
      end

      def valid_request_methods
        if @user_or_group.is_a?(User)
          Webui::Users::BsRequestsController::REQUEST_METHODS.values
        else
          Webui::Groups::BsRequestsController::REQUEST_METHODS.values
        end
      end
    end
  end
end
