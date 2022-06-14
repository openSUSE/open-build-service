class Webui::Users::Tokens::UsersController < Webui::WebuiController
  before_action :set_token
  before_action :set_user_via_userid, only: :create
  before_action :set_user, only: :destroy

  def index
    @users = @token.users_shared_among
    @groups = @token.groups_shared_among
  end

  def create
    authorize @token

    @token.users_shared_among << @user unless @token.users_shared_among.include?(@user)
    redirect_to token_users_path(@token), success: "User #{@user.login} now owns the token"
  end

  def destroy
    authorize @token

    @token.users_shared_among.delete(@user)
    redirect_to token_users_path(@token), success: "User #{@user.login} does not own the token anymore"
  end

  private

  def set_token
    @token = Token::Workflow.find(params[:token_id])
  end

  def set_user_via_userid
    @user = User.find_by!(login: params[:userid])
  end

  def set_user
    @user = User.find(params[:id])
  end
end
