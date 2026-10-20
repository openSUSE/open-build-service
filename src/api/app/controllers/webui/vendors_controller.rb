class Webui::VendorsController < Webui::WebuiController
  #### Includes and extends
  include Webui::PreviewDescription

  #### Constants

  #### Self config

  #### Callbacks macros: before_action, after_action, etc.
  before_action :check_beta_feature
  before_action :set_project
  before_action :set_vendor, only: %i[update destroy]
  # Pundit authorization policies control
  after_action :verify_authorized

  #### CRUD actions

  # GET /vendor
  # The vendor is displayed in the project overview, we keep this route for existing links.
  def show
    skip_authorization
    redirect_to project_show_path(@project, anchor: 'vendor')
  end

  # POST /vendors
  def create
    @vendor = Vendor.new(vendor_params)
    @vendor.project = @project
    authorize @vendor
    if @vendor.save
      redirect_to project_show_path(@project, anchor: 'vendor'), flash: { success: 'Vendor was successfully created.' }
    else
      redirect_to project_show_path(@project), flash: { error: "Vendor failed to create. #{@vendor.errors.full_messages.to_sentence}" }
    end
  end

  # PATCH/PUT /vendors/1
  def update
    authorize @vendor
    if @vendor.update(vendor_params)
      redirect_to project_show_path(@project, anchor: 'vendor'), flash: { success: 'Vendor was successfully updated.' }
    else
      redirect_to project_show_path(@project, anchor: 'vendor'),
                  flash: { error: "Vendor failed to update. #{@vendor.errors.full_messages.to_sentence}" }
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
    @vendor = @project.vendor
  end

  # Only allow a trusted parameter "white list" through.
  def vendor_params
    params.expect(vendor: %i[name description url])
  end
end
