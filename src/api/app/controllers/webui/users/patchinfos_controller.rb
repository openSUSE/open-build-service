module Webui
  module Users
    class PatchinfosController < WebuiController
      before_action :require_login

      def index
        respond_to do |format|
          format.json do
            render json: TasksMaintenanceRequestsDatatable.new(current_user: User.session, view_context: view_context)
          end
        end
      end
    end
  end
end
