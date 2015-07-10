class Webui::NotificationsController < Webui::WebuiController
  include Webui::NotificationSettings

  before_filter :require_admin

  def index
    @notifications = notifications_for_user
  end

  def bulk_update
    update_notifications_for_user(params)

    flash[:notice] = 'Notifications settings updated'
    redirect_to action: :index
  end
end
