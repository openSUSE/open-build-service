# typed: false
class Webui::InterconnectsController < Webui::WebuiController
  before_action :require_admin

  def new
    @interconnect = RemoteProject.new(default_values)
    switch_to_webui2
  end

  def create
    switch_to_webui2

    @project = RemoteProject.new(project_params)

    respond_to do |format|
      if @project.valid? && @project.store
        logger.debug "New remote project with url #{@project.remoteurl}"
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
          redirect_back(fallback_location: root_path, error: message)
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

  def default_values
    return if Project.exists?(name: 'openSUSE.org')

    { name: 'openSUSE.org',
      remoteurl: 'https://api.opensuse.org/public',
      title: 'Remote OBS instance',
      description: 'This project is representing a remote build service instance.' }
  end
end
