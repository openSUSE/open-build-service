class Webui::Users::AnnouncementsController < Webui::WebuiController
  before_action :require_login

  def create
    announcement = Announcement.find_by(id: params[:id])
    if announcement
      User.current.announcements << announcement
    else
      flash.now[:error] = "Couldn't find Announcement"
    end
  end
end
