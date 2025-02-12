class Webui::Users::TokensController < Webui::WebuiController
  before_action :require_login
  before_action :set_token, only: %i[edit update destroy show]
  before_action :set_parameters, :set_package, only: [:create]

  after_action :verify_authorized, only: %i[create update destroy]
  after_action :verify_policy_scoped, only: %i[index show edit]

  def index
    @tokens = policy_scope(Token).page(params[:page])
  end

  def show; end

  def new
    @token = User.session.tokens.new
  end

  def edit; end

  def create
    @token = Token.token_type(@params[:type]).new(@params.except(:type).merge(executor: User.session, package: @package))

    authorize @token

    respond_to do |format|
      format.html do
        if @token.save
          flash[:success] = "Token successfully created! Make sure you save it - you won't be able to access it again."
          session[:show_token] = 'true'
          redirect_to token_path(@token)
        else
          flash[:error] = "Failed to create token: #{@token.errors.full_messages.to_sentence}."
          render :new
        end
      end
    end
  end

  def update
    authorize @token

    respond_to do |format|
      format.js do
        if @token.regenerate_string
          flash.now[:success] = "Token string successfully regenerated! Make sure you save it - you won't be able to access it again."
          render partial: 'update', locals: { string: @token.string }
        else
          flash.now[:error] = "Failed to regenerate Token string: #{@token.errors.full_messages.to_sentence}"
          render partial: 'update'
        end
      end
      format.html do
        if @token.update(update_parameters)
          flash[:success] = 'Token successfully updated'
        else
          flash[:error] = "Failed to update Token: #{@token.errors.full_messages.to_sentence}"
        end

        redirect_to tokens_url
      end
    end
  end

  def destroy
    authorize @token

    if @token.destroy
      flash[:success] = 'Token was successfully deleted.'
    else
      flash[:error] = "Failed to destroy Token: #{@token.errors.full_messages.to_sentence}"
    end
    redirect_to tokens_url
  end

  private

  def set_token
    @token = policy_scope(Token).find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to tokens_url
  end

  def set_parameters
    @params = params.except(:project_name, :package_name).require(:token).except(:string_readonly)
                    .permit(:type, :description, :scm_token, :workflow_configuration_path, :workflow_configuration_url).tap do |token_parameters|
      token_parameters.require(:type)
    end
    @params = @params.except(:scm_token, :workflow_configuration_path, :workflow_configuration_url) unless @params[:type] == 'workflow'
    @extra_params = params.slice(:project_name, :package_name).permit!
  end

  def update_parameters
    params.require(:token).except(:string_readonly).permit(:description, :enabled, :scm_token, :workflow_configuration_path, :workflow_configuration_url)
          .reject! { |k, v| k == 'scm_token' && (@token.type != 'Token::Workflow' || v.empty?) }
  end

  def set_package
    return if @extra_params[:project_name].blank? && @extra_params[:package_name].blank?

    # Prevent setting a package for a workflow token
    return if @params[:type] == 'workflow'

    @token = Token.new(description: @params[:description])
    @token.write_attribute(:type, @params[:type])

    # Check if only project_name or only package_name are present
    if @extra_params[:project_name].present? ^ @extra_params[:package_name].present?
      flash[:error] = 'When providing an optional package, both Project name and Package name must be provided.'
      render :new and return
    end

    # If both project_name and package_name are present, check if this is an existing package
    begin
      @package = Package.get_by_project_and_name(@extra_params[:project_name], @extra_params[:package_name])
    rescue Project::UnknownObjectError
      flash[:error] = "When providing an optional package, the package must exist. Project '#{elide(@extra_params[:project_name])}' does not exist."
      render :new
    rescue Package::UnknownObjectError
      flash[:error] = 'When providing an optional package, the package must exist. ' \
                      "Package '#{elide(@extra_params[:project_name])}/#{elide(@extra_params[:package_name])}' does not exist."
      render :new
    end
  end
end
