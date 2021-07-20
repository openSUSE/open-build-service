class Webui::Users::TokensController < Webui::WebuiController
  before_action :set_token, only: [:destroy]

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @tokens = policy_scope([:webui, Token]).page(params[:page])
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
end
