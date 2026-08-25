class Webui::VendorsController < Webui::WebuiController
  #### Includes and extends

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :check_beta_feature
  before_action :set_project
  before_action :set_vendor, only: %i[show edit update destroy]
  before_action :verify_project, only: %i[show edit update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /vendors/1
  def show
    if @vendor.present?
      authorize @vendor
    else
      skip_authorization
    end
  end

  # GET /vendors/new
  def new
    @vendor = Vendor.new(project: @project)
    authorize @vendor
  end

  # GET /vendors/1/edit
  def edit
    authorize @vendor
  end

  # POST /vendors
  def create
    @vendor = Vendor.new(vendor_params)
    @vendor.project = @project
    authorize @vendor
    if @vendor.save
      redirect_to [@project, @vendor], flash: { success: 'Vendor was successfully created.' }
    else
      render :new
    end
  end

  # PATCH/PUT /vendors/1
  def update
    authorize @vendor
    if @vendor.update(vendor_params)
      redirect_to [@project, @vendor], flash: { success: 'Vendor was successfully updated.' }
    else
      render :edit
    end
  end

  # DELETE /vendors/1
  def destroy
    authorize @vendor
    @vendor.destroy!
    redirect_to project_show_path(@project), flash: { success: 'Vendor was successfully destroyed.' }
  end

  #### Non CRUD actions

  #### Non actions methods
  # Use hide_action if they are not private

  private

  def check_beta_feature
    redirect_to root_path unless Flipper.enabled?(:enhanced_distribution_support, User.session)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_vendor
    @vendor = Vendor.find(params.expect(:id))
  end

  # Only allow a trusted parameter "white list" through.
  def vendor_params
    params.expect(vendor: %i[name description url])
  end
end
