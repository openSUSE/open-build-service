class Webui::ActionSeenByUsersController < Webui::WebuiController
  before_action :require_login

  def toggle_action_seen_by_user
    @action = BsRequestAction.find(params[:action_id])
    @user = User.session

    if @action.seen_by_users.exists?({ id: @user.id })
      @action.seen_by_users.destroy(@user)
    else
      @action.seen_by_users << @user
    end

    respond_to do |format|
      format.js
    end
  end
end
