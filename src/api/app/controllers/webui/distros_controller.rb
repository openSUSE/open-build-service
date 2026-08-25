class Webui::DistrosController < Webui::WebuiController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_vendor
  before_action :set_project
  before_action :set_distro, only: %i[update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # POST /distros
  def create
    @distro = Distro.new(distro_params)
    authorize @distro
    if @distro.save
      redirect_to project_vendor_path(@project), notice: 'Distro was successfully created.'
    else
      redirect_to project_vendor_path(@project), flash: { error: "Distro failed to create. #{@distro.errors.messages}" }
    end
  end

  # PATCH/PUT /distros/1
  def update
    authorize @distro
    if @distro.update(distro_params)
      redirect_to project_vendor_path(@project), flash: { success: 'Distro was successfully updated.' }
    else
      redirect_to project_vendor_path(@project), flash: { error: "Distro failed to update. #{@distro.errors.messages}" }
    end
  end

  # DELETE /distros/1
  def destroy
    authorize @distro
    @distro.destroy!
    redirect_to project_vendor_path(@project), flash: { success: 'Distro was successfully destroyed.' }
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_distro
    @distro = Distro.find(params.expect(:id))
  end

  # Only allow a trusted parameter "white list" through.
  def distro_params
    params.expect(distro: %i[vendor_id name description url])
  end

  def set_vendor
    @vendor = Vendor.find(params.expect(:vendor_id))
  end

  def set_project
    @project = @vendor.project
  end
end
