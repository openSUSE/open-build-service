class Webui::DistroReleaseRepositoryArchitectyresController < Webui::WebuiController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_project
  before_action :set_distro
  before_action :set_vendor
  before_action :set_distro_release
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  def edit
    authorize @distro_release
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_distro
    @distro = @project.distros.find_by!(name: params.expect(:distro_name))
  end

  def set_vendor
    @vendor = @distro.vendor
  end

  # Only allow a trusted parameter "white list" through.
  def distro_release_params
    params.expect(distro_release: [:name, :description, :url, { repository_architecture_ids: [] }])
  end

  def set_distro_release
    @distro_release = @distro.distro_releases.find_by!(name: params.expect(:release_name))
  end
end
