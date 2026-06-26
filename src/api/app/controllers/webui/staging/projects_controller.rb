module Webui
  module Staging
    class ProjectsController < WebuiController
      before_action :set_workflow_project
      before_action :set_staging_workflow
      after_action :verify_authorized, except: :show

      def show
        @staging_project = @staging_workflow.staging_projects.find_by(name: params[:project_name])

        unless @staging_project
          redirect_back_or_to staging_workflow_path(@staging_workflow)
          flash[:error] = "Staging Project \"#{elide(params[:project_name])}\" doesn't exist for this Staging."
          return
        end

        @staging_project_log_entries = @staging_project.project_log_entries
                                                       .staging_history
                                                       .includes(:bs_request)
                                                       .order(datetime: :desc)
        @project = @staging_workflow.project

        @groups_hash = ::Staging::Workflow.load_groups
        @users_hash = ::Staging::Workflow.load_users(@staging_project)
      end

      def create
        authorize @staging_workflow

        staging_project = Project.where.not(id: @staging_workflow.project_id)
                                 .find_or_initialize_by(name: params[:staging_project_name])
        authorize(staging_project, :create?)

        redirect_to edit_staging_workflow_path(@staging_workflow.project)

        if staging_project.staging_workflow_id?
          flash[:error] = "\"#{elide(staging_project.name)}\" is already assigned to a staging workflow"
          return
        end

        staging_project.staging_workflow = @staging_workflow

        if staging_project.valid? && staging_project.store
          flash[:success] = "Staging project with name = \"#{elide(staging_project.name)}\" was successfully created"
          CreateProjectLogEntryJob.perform_later(project_log_entry_payload(staging_project), staging_project.created_at.to_s, staging_project.class.name)
          return
        end

        flash[:error] = "#{elide(staging_project.name)} couldn't be created: #{staging_project.errors.full_messages.to_sentence}"
      end

      def destroy
        authorize @staging_workflow

        staging_project = @staging_workflow.staging_projects.find_by(name: params[:project_name])

        unless staging_project
          redirect_back_or_to edit_staging_workflow_path(@staging_workflow.project)
          flash[:error] = "Staging Project \"#{elide(params[:project_name])}\" doesn't exist for this Staging"
          return
        end

        if staging_project.staged_requests.present?
          redirect_back_or_to edit_staging_workflow_path(@staging_workflow.project)
          flash[:error] = "Staging Project \"#{elide(params[:project_name])}\" could not be deleted because it has staged requests."
          return
        end

        if staging_project.destroy
          flash[:success] = "Staging Project \"#{elide(params[:project_name])}\" was deleted."
        else
          flash[:error] = "#{elide(staging_project.name)} couldn't be deleted: #{staging_project.errors.full_messages.to_sentence}"
        end

        redirect_to edit_staging_workflow_path(@staging_workflow.project)
      end

      def preview_copy
        authorize @staging_workflow

        @staging_project = @staging_workflow.staging_projects.find_by(name: params[:project_name])
        @project = @staging_workflow.project
      end

      def copy
        authorize @staging_workflow

        StagingProjectCopyJob.perform_later(@staging_workflow.project.name, params[:project_name], params[:staging_project_copy_name], User.session.id)

        flash[:success] = "Job to copy the staging project #{elide(params[:project_name])} successfully queued."

        redirect_to edit_staging_workflow_path(@staging_workflow.project)
      end

      private

      def project_log_entry_payload(staging_project)
        # TODO: model ProjectLogEntry should be able to work with symbols
        { 'project' => staging_project, 'user_name' => User.session, 'event_type' => 'staging_project_created' }
      end

      def set_workflow_project
        @project = Project.find_by!(name: params[:workflow_project])
      end

      def set_staging_workflow
        @staging_workflow = @project.staging
        return if @staging_workflow

        flash[:error] = 'Staging project not found'
        redirect_back_or_to root_path
      end
    end
  end
end
