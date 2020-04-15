class Webui::Users::NotificationsController < Webui::WebuiController
  before_action :require_login

  def index
    notifications_for_subscribed_user = NotificationsFinder.new.for_subscribed_user
    @notifications = NotificationsFinder.new(notifications_for_subscribed_user).for_notifiable_type(params[:type])
    @notifications = @notifications.page(params[:page])
  end

  def update
    notification = User.session.notifications.find(params[:id])
    authorize notification, policy_class: NotificationPolicy

    if notification.toggle(:delivered).save
      flash[:success] = "Successfully marked the notification as #{notification.unread? ? 'unread' : 'read'}"
    else
      flash[:error] = "Couldn't mark the notification as #{notification.unread? ? 'read' : 'unread'}"
    end
    redirect_back(fallback_location: root_path)
  end
end
