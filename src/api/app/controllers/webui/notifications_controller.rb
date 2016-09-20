class Webui::NotificationsController < Webui::WebuiController
  before_action :require_admin

  def index
    @notifications = Event::Base.notification_events
  end

  def bulk_update
    User.update_notifications(params)

    flash[:notice] = 'Notifications settings updated'
    redirect_to action: :index
  end
end
