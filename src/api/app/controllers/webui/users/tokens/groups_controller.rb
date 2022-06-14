class Webui::Users::Tokens::GroupsController < Webui::WebuiController
  before_action :set_token
  before_action :set_group_via_groupid, only: :create
  before_action :set_group, only: :destroy

  def create
    authorize @token

    @token.groups_shared_among << @group unless @token.groups_shared_among.include?(@group)
    redirect_to token_users_path(@token), success: "Group #{@group.title} now owns the token"
  end

  def destroy
    authorize @token

    @token.groups_shared_among.destroy(@group)
    redirect_to token_users_path(@token), success: "Group #{@group.title} does not own the token anymore"
  end

  private

  def set_token
    @token = Token::Workflow.find(params[:token_id])
  end

  def set_group_via_groupid
    @group = Group.find_by!(title: params[:groupid])
  end

  def set_group
    @group = Group.find(params[:id])
  end
end
