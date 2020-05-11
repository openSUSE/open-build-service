module Webui
  module Projects
    class MaintainedProjectsController < WebuiController
      before_action :set_project
      before_action :set_maintained_project, except: [:index]
      after_action :verify_authorized, except: [:index]

      def index
        respond_to do |format|
          format.html
          format.json do
            render json: MaintainedProjectDatatable.new(params, view_context: view_context,
                                                                project: @project, current_user: User.possibly_nobody)
          end
        end
      end

      def destroy
        authorize @project, :destroy?

        maintenance_project = MaintainedProject.find_by!(project: @maintained_project)

        @project.maintained_projects.destroy(maintenance_project)

        flash_message = if @project.valid? && @project.store
                          { success: "Disabled maintenance for #{maintenance_project.project}" }
                        else
                          { error: "Failed to disable Maintenance for #{maintenance_project.project}: #{@project.errors.full_messages.to_sentence}" }
                        end

        redirect_to(project_maintained_projects_path(project_name: @project.name), flash_message)
      end

      def create
        authorize @project, :update?

        @project.maintained_projects.create!(project: @maintained_project)

        flash_message = if @project.valid? && @project.store
                          { success: "Enabled Maintenance for #{@maintained_project}" }
                        else
                          { error: "Failed to enable Maintenance for #{@maintained_project}: #{@project.errors.full_messages.to_sentence}" }
                        end

        redirect_to(project_maintained_projects_path(project_name: @project.name), flash_message)
      end

      private

      def set_maintained_project
        @maintained_project = Project.find_by!(name: params[:maintained_project])
      end
    end
  end
end
