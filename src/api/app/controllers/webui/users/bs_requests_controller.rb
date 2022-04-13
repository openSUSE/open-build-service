module Webui
  module Users
    class BsRequestsController < WebuiController
      include Webui::Mixins::BsRequestsControllerMixin
      before_action :require_login
      before_action :set_user

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_out_table' => :outgoing_requests,
        'requests_declined_table' => :declined_requests,
        'requests_in_table' => :incoming_requests,
        'reviews_in_table' => :involved_reviews
      }.freeze

      private

      def set_user
        @user_or_group = User.session!
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]] || :requests
      end
    end
  end
end
