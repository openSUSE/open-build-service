class Webui::Users::TokensController < Webui::WebuiController
  before_action :set_token, only: [:destroy]
  before_action :set_params, :set_package, :set_scm_token, only: [:create]

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
    @token = Token.token_type(@params[:operation]).new(@params.merge(user: User.session))

    authorize [:webui, @token]

    @token.save

    respond_to do |format|
      format.js do
        render partial: 'create', locals: {
          string: @token.string,
          flash: { success: "Token successfully created! Make sure you save it - you won't be able to access it again." }
        }
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
    @package = Package.get_by_project_and_name(@params[:project_name], @params[:package_name]) if @params[:project_name].present? && @params[:package_name].present?
  end

  def set_scm_token
    return unless @params[:operation] == 'workflow'

    @scm_token = @params[:scm_token]
  end
end
