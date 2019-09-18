module Webui
  module Staging
    class ProjectsController < WebuiController
      before_action :require_login
      before_action :set_staging_workflow
      after_action :verify_authorized, except: :show

      def create
        authorize @staging_workflow

        staging_project = Project.where.not(id: @staging_workflow.project_id)
                                 .find_or_initialize_by(name: params[:staging_project_name])
        authorize(staging_project, :create?)

        redirect_to edit_staging_workflow_path(@staging_workflow)

        if staging_project.staging_workflow_id?
          flash[:error] = "\"#{staging_project}\" is already assigned to a staging workflow"
          return
        end

        staging_project.staging_workflow = @staging_workflow

        if staging_project.valid? && staging_project.store
          flash[:success] = "Staging project with name = \"#{staging_project}\" was successfully created"
          staging_project.create_project_log_entry(User.session!)

          return
        end

        flash[:error] = "#{staging_project} couldn't be created: #{staging_project.errors.full_messages.to_sentence}"
      end

      def show
        @staging_project = @staging_workflow.staging_projects.find_by(name: params[:project_name])
        @staging_project_log_entries = @staging_project.project_log_entries
                                                       .where(event_type: [:staging_project_created, :staged_request, :unstaged_request])
                                                       .includes(:bs_request)
                                                       .order(datetime: :desc)
        @project = @staging_workflow.project

        @groups_hash = ::Staging::Workflow.load_groups
        @users_hash = ::Staging::Workflow.load_users(@staging_project)
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

      def preview_copy
        authorize @staging_workflow

        @staging_project = @staging_workflow.staging_projects.find_by(name: params[:staging_project_project_name])
        @project = @staging_workflow.project
      end

      def copy
        authorize @staging_workflow

        StagingProjectCopyJob.perform_later(@staging_workflow.project.name, params[:staging_project_project_name], params[:staging_project_copy_name], User.session!.id)

        flash[:success] = "Job to copy the staging project #{params[:staging_project_project_name]} successfully queued."

        redirect_to edit_staging_workflow_path(@staging_workflow)
      end

      private

      def set_staging_workflow
        @staging_workflow = ::Staging::Workflow.find(params[:staging_workflow_id])
      end
    end
  end
end
