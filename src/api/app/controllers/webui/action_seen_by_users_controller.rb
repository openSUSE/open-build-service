class Webui::ActionSeenByUsersController < Webui::WebuiController
  before_action :require_login

  def toggle
    @action = BsRequestAction.find(params[:action_id])
    @user = User.session

    @action.toggle_seen_by(@user)

    respond_to do |format|
      format.js
    end
  end
end
