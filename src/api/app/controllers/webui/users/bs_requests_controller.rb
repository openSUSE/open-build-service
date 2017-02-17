module Webui
  module Users
    class BsRequestsController < WebuiController
      before_action :check_display_user

      def index
        @requests_data_table = BsRequest::DataTable.new(params, @displayed_user)
        respond_to do |format|
          format.json
        end
      end
    end
  end
end
