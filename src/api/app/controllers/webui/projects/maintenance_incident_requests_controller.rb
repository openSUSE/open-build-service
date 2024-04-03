module Webui
  module Projects
    class MaintenanceIncidentRequestsController < WebuiController
      before_action :set_project
      before_action :lockout_spiders, only: [:new]
      before_action :require_login

      after_action :verify_authorized

      def new
        authorize @project, :update?

        @release_targets = []
        return if @project.release_targets.empty?

        @project.repositories.each do |repository|
          release_target = repository.release_targets.first
          @release_targets.push("#{release_target.repository.project.name}/#{release_target.repository.name}") if release_target
        end
      end

      def create
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
          redirect_back_or_to project_show_path(@project)
          return
        end
        redirect_to(project_show_path(@project))
      end
    end
  end
end
