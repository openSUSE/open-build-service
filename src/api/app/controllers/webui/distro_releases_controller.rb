class Webui::DistroReleasesController < Webui::WebuiController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_distro
  before_action :set_distro_release, only: %i[update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  def create
    @distro_release = @distro.distro_releases.new(distro_release_params)
    authorize @distro_release
    if @distro_release.save
      redirect_to project_distro_path(@distro.project, @distro.name), notice: 'Release was successfully created.'
    else
      redirect_to project_distro_path(@distro.project, @distro.name), flash: { error: "Release failed to create. #{@distro_release.errors.messages}" }
    end
  end

  def update
    authorize @distro_release
    if @distro_release.update(distro_release_params)
      redirect_to project_distro_path(@distro.project, @distro.name), flash: { success: 'Release was successfully updated.' }
    else
      redirect_to project_distro_path(@distro.project, @distro.name), flash: { error: "Release failed to update. #{@distro.errors.messages}" }
    end
  end

  def destroy
    authorize @distro_release
    @distro_release.destroy!
    redirect_to project_distro_path(@distro.project, @distro.name), flash: { success: 'Release was successfully destroyed.' }
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_distro
    @distro = Distro.find_by!(name: params.expect(:distro_name))
  end

  # Only allow a trusted parameter "white list" through.
  def distro_release_params
    params.expect(distro_release: [:name, :description, :url, { repository_architecture_ids: [] }])
  end

  def set_distro_release
    @distro_release = @distro.distro_releases.find_by!(name: params.expect(:distro_release_name))
  end
end
