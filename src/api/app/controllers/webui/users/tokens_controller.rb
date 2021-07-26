class Webui::Users::TokensController < Webui::WebuiController
  before_action :set_token, only: [:destroy]
  before_action :set_params, :set_package, only: [:create]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @tokens = policy_scope([:webui, Token]).page(params[:page])
  end

  def new
    @token = Token.new
    authorize [:webui, @token]
  end

  def create
    @token = Token.token_type(@params[:operation]).new(@params.merge(user: User.session, package: @package))

    authorize [:webui, @token]

    respond_to do |format|
      format.js do
        if @token.save
          flash.now[:success] = "Token successfully created! Make sure you save it - you won't be able to access it again."
          render partial: 'create', locals: { string: @token.string }
        else
          flash.now[:error] = "Failed to create token: #{@token.errors.full_messages.to_sentence}."
          render partial: 'create'
        end
      end
    end
  end

  def destroy
    authorize [:webui, @token]
    @token.destroy
    flash[:success] = 'Token was successfully deleted.'
    redirect_to tokens_url
  end

  private

  def set_token
    @token = Token.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to tokens_url
  end

  def set_params
    @params = params.require(:token).except(:string_readonly).permit(:operation, :project_name, :package_name, :scm_token).tap do |token_parameters|
      token_parameters.require(:operation)
    end
  end

  def set_package
    return if @params[:project_name].blank? && @params[:package_name].blank?

    # Prevent setting a package for a workflow token
    return if @params[:operation] == 'workflow'

    # Check if only project_name or only package_name are present
    if @params[:project_name].present? ^ @params[:package_name].present?
      flash.now[:error] = 'When providing an optional package, both Project name and Package name must be provided.'
      render partial: 'create' and return
    end

    # If both project_name and package_name are present, check if this is an existing package
    begin
      @package = Package.get_by_project_and_name(@params[:project_name], @params[:package_name])
    rescue Project::UnknownObjectError
      flash.now[:error] = "When providing an optional package, the package must exist. Project '#{@params[:project_name]}' does not exist."
      render partial: 'create'
    rescue Package::UnknownObjectError
      flash.now[:error] = "When providing an optional package, the package must exist. Package '#{@params[:project_name]}/#{@params[:package_name]}' does not exist."
      render partial: 'create'
    end
  end
end
