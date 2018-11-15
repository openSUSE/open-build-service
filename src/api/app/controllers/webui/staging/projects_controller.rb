module Webui
  module Staging
    class ProjectsController < WebuiController
      layout 'webui2/webui'

      before_action :require_login
      before_action :set_staging_workflow
      after_action :verify_authorized

      def create
        authorize @staging_workflow

        staging_project_name = "#{@staging_workflow.project}:Staging:#{params[:staging_project_name]}"
        staging_project = @staging_workflow.staging_projects.build(name: staging_project_name)
        staging_project.assign_managers_group(@staging_workflow.managers_group)

        if staging_project.valid? && staging_project.store
          flash[:success] = "Staging project with name = \"#{staging_project}\" was successfully created"
        else
          flash[:error] = "#{staging_project} couldn't be created: #{staging_project.errors.full_messages.to_sentence}"
        end

        redirect_to edit_staging_workflow_path(@staging_workflow)
      end

      def destroy
        authorize @staging_workflow

        staging_project = @staging_workflow.staging_projects.find_by(name: params[:project_name])

        unless staging_project
          redirect_back(fallback_location: edit_staging_workflow_path(@staging_workflow))
          flash[:error] = "Staging Project with name = \"#{params[:project_name]}\" doesn't exist for this StagingWorkflow"
          return
        end

        if staging_project.destroy
          flash[:success] = "Staging Project \"#{params[:project_name]}\" was deleted."
        else
          flash[:error] = "#{staging_project} couldn't be deleted: #{staging_project.errors.full_messages.to_sentence}"
        end

        redirect_to edit_staging_workflow_path(@staging_workflow)
      end

      private

      def set_staging_workflow
        @staging_workflow = ::Staging::Workflow.find(params[:staging_workflow_id])
        return if @staging_workflow

        redirect_back(fallback_location: root_path)
        flash[:error] = "Staging with id = #{params[:staging_workflow_id]} doesn't exist"
        return
      end
    end
  end
end
