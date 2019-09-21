class Webui::UserController < Webui::WebuiController
  def home
    if params[:user].present?
      redirect_to user_path(params[:user])
    else
      redirect_to user_path(User.possibly_nobody)
    end
  end
end
