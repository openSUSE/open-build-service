class Webui::InterconnectsController < Webui::WebuiController
  before_action :require_admin

  def new
    @interconnect = RemoteProject.new(default_values)
    # TODO: Remove the statement after migration is finished
    switch_to_webui2 if Rails.env.development? || Rails.env.test?
  end

  def create
    @project = RemoteProject.new(project_params)

    if @project.valid? && @project.store
      flash[:notice] = "Project '#{@project.name}' was created successfully"
      logger.debug "New remote project with url #{@project.remoteurl}"
      redirect_to project_show_path(project: @project.name)
    else
      redirect_back(fallback_location: root_path, error: "Project can't be saved: #{@project.errors.full_messages.to_sentence}")
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
