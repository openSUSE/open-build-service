class Webui::DistrosController < Webui::WebuiController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :set_vendor
  before_action :set_distro, only: %i[edit update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /distros/new
  def new
    @distro = Distro.new(project: @project)
    authorize @distro
  end

  # GET /distros/1/edit
  def edit
    authorize @distro
  end

  # POST /distros
  def create
    @distro = Distro.new(distro_params)
    authorize @distro
    if @distro.save
      redirect_to [@project, @distro], notice: 'Distro was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /distros/1
  def update
    authorize @distro
    if @distro.update(distro_params)
      redirect_to [@project, @distro], flash: { success: 'Distro was successfully updated.' }
    else
      render :edit
    end
  end

  # DELETE /distros/1
  def destroy
    authorize @distro
    @distro.destroy!
    redirect_to project_show_path(@project), flash: { success: 'Distro was successfully destroyed.' }
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
    params.expect(distro: %i[project_id name description url])
  end

  def set_vendor
    @vendor = Vendor.find(params.expect(:vendor_id))
  end
end
