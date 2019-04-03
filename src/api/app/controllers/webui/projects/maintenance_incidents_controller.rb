module Webui
  module Projects
    class MaintenanceIncidentsController < WebuiController
      before_action :set_project, only: [:index, :create_request]
      before_action :lockout_spiders, only: [:index]
      before_action :require_login, only: [:create, :create_request]

      after_action :verify_authorized, except: [:index]

      def index
        @incidents = @project.maintenance_incidents
      end

      def create
        @project = Project.get_by_name(params[:project_name])
        authorize @project, :update?

        incident = MaintenanceIncident.build_maintenance_incident(@project, params[:noaccess].present?)

        if incident
          flash[:success] = "Created maintenance incident project #{incident.project}"
          redirect_to(project_show_path(incident.project))
          return
        end

        flash[:error] = 'Incident projects shall only create below maintenance projects.'
        redirect_to(project_show_path(@project))
      end

      def create_request
        authorize @project, :update?

        begin
          BsRequest.transaction do
            req = BsRequest.new
            req.description = params[:description]

            action = BsRequestActionMaintenanceIncident.new(source_project: @project)
            req.bs_request_actions << action

            req.set_add_revision
            req.save!
          end
          flash[:success] = 'Created maintenance incident request'
        rescue MaintenanceHelper::MissingAction, BsRequestAction::UnknownProject, BsRequestAction::UnknownTargetPackage => e
          flash[:error] = e.message
          redirect_back(fallback_location: project_show_path(@project))
          return
        end
        redirect_to(project_show_path(@project))
      end
    end
  end
end
