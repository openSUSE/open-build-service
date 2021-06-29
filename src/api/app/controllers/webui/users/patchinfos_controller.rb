module Webui
  module Users
    class PatchinfosController < WebuiController
      after_action :verify_authorized

      def index
        authorize [:users, :patchinfos]

        respond_to do |format|
          format.json do
            render json: TasksMaintenanceRequestsDatatable.new(current_user: User.session!, view_context: view_context)
          end
        end
      end
    end
  end
end
