class Webui::InterconnectsController < Webui::WebuiController
  before_action :require_admin

  def create
    @project = RemoteProject.new(project_params)

    respond_to do |format|
      if @project.valid? && @project.store
        logger.debug "New remote project with url #{@project.remoteurl}"
        # Schedule a distribution refresh
        FetchRemoteDistributionsJob.perform_later
        message = "Project '#{@project}' was successfully created."
        format.html do
          flash[:success] = message
          redirect_to project_show_path(project: @project)
        end
        format.js do
          flash.now[:success] = message
          render :create, status: :ok, locals: { interconnect: project_params }
        end
      else
        message = "Failed to create project '#{@project}': #{@project.errors.full_messages.to_sentence}"
        format.html do
          redirect_back_or_to root_path, error: message
        end
        format.js do
          flash.now[:error] = message
          render :create, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :title, :remoteurl, :description)
  end
end
