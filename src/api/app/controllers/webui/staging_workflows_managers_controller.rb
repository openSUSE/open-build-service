class Webui::StagingWorkflowsManagersController < Webui::WebuiController
  layout 'webui2/webui'

  before_action :set_bootstrap_views
  before_action :set_staging_workflow
  before_action :set_project
  before_action :require_login, except: [:index]

  after_action :verify_authorized, except: [:index]

  def index
    @staging_managers = @staging_workflow.managers
  end

  def create
    authorize(@staging_workflow, :update?)

    begin
      staging_manager = User.find_by_login!(params[:staging_manager])

      if @staging_workflow.managers << staging_manager
        flash[:success] = "Staging manager #{staging_manager.login} for #{@project} was successfully added"
      else
        flash[:error] = "Staging manager #{staging_manager.login} for #{@project} couldn't be added"
      end
    rescue NotFoundError => error
      flash[:error] = error.to_s
    rescue ActiveRecord::RecordNotUnique
      flash[:error] = "#{staging_manager.login} is already a staging manager for #{@project}"
    end

    redirect_to action: :index
  end

  def destroy
    authorize(@staging_workflow, :update?)

    begin
      staging_manager = User.find(params[:id])

      if @staging_workflow.managers.delete(staging_manager)
        flash[:success] = "Staging manager #{staging_manager.login} for #{@project} was successfully removed"
      else
        flash[:error] = "Staging manager #{staging_manager.login} for #{@project} couldn't be removed"
      end
    rescue NotFoundError => error
      flash[:error] = error.to_s
    end

    redirect_to action: :index
  end

  private

  def set_bootstrap_views
    prepend_view_path('app/views/webui2')
  end

  def set_staging_workflow
    @staging_workflow = StagingWorkflow.find_by(id: params[:staging_workflow_id])
  end

  def set_project
    @project = @staging_workflow.project
  end
end
