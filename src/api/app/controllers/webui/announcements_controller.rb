class Webui::AnnouncementsController < Webui::WebuiController
  def show
    @hide_announcement_notification = true
    @announcement = Announcement.find_by(id: params[:id])

    redirect_back(fallback_location: root_path, error: "Couldn't find announcement") unless @announcement
  end
end
