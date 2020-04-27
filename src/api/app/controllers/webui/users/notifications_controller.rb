class Webui::Users::NotificationsController < Webui::WebuiController
  before_action :require_login
  MAX_PER_PAGE = 300

  def index
    notifications_for_subscribed_user = User.session.notifications.for_web
    @notifications = NotificationsFinder.new(notifications_for_subscribed_user).for_notifiable_type(params[:type])
    @notifications = params['show_all'] ? show_all : @notifications.page(params[:page])
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

  private

  def show_all
    total = @notifications.size
    if total > MAX_PER_PAGE
      flash.now[:info] = "You have too many notifications. Displaying a maximum of #{MAX_PER_PAGE} notifications per page."
    end
    @notifications = @notifications.page(params[:page]).per([total, MAX_PER_PAGE].min)
  end
end
