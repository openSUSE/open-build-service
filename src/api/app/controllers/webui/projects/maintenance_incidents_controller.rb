module Webui
  module Projects
    class MaintenanceIncidentsController < WebuiController
      before_action :set_project, only: [:index]
      before_action :lockout_spiders, only: [:index]
      before_action :require_login, only: [:create]

      after_action :verify_authorized, except: [:index]

      def index
        respond_to do |format|
          format.html do
            @incidents = @project.maintenance_incidents
          end
          format.json do
            render json: MaintenanceIncidentDatatable.new(params, view_context: view_context, project: @project)
          end
        end
      end

      def create
        @project = Project.get_by_name(params[:project_name])
        authorize @project, :update?

        incident = MaintenanceIncident.build_maintenance_incident(@project, no_access: params[:noaccess].present?)

        if incident
          flash[:success] = "Created maintenance incident project #{elide(incident.project.name)}"
          redirect_to(project_show_path(incident.project))
          return
        end

        flash[:error] = 'Incident projects shall only create below maintenance projects.'
        redirect_to(project_show_path(@project))
      end
    end
  end
end
