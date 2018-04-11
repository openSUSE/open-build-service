# frozen_string_literal: true

module Webui
  module Groups
    class BsRequestsController < WebuiController
      include Webui::Mixins::BsRequestsControllerMixin
      before_action :set_group

      REQUEST_METHODS = {
        'all_requests_table' => :requests,
        'requests_in_table'  => :incoming_requests,
        'reviews_in_table'   => :involved_reviews
      }.freeze

      private

      def set_group
        @user_or_group = Group.find_by_title!(params[:title])
      end

      def request_method
        REQUEST_METHODS[params[:dataTableId]]
      end
    end
  end
end
