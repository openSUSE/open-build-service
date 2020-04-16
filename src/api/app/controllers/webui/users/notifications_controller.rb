class Webui::Users::NotificationsController < Webui::WebuiController
  before_action :require_login

  def index
    notification_type = params[:type]
    case notification_type
    when 'read'
      @notifications = Notification.with_notifiable.where(delivered: true)
                                   .for_subscribed_user(User.session)
    when 'reviews'
      @notifications = Notification.with_notifiable.unread
                                   .where(notifiable_type: 'Review')
                                   .for_subscribed_user(User.session)
    when 'comments'
      @notifications = Notification.with_notifiable.unread
                                   .where(notifiable_type: 'Comment')
                                   .for_subscribed_user(User.session)
    when 'requests'
      @notifications = Notification.with_notifiable.unread
                                   .where(notifiable_type: 'BsRequest')
                                   .for_subscribed_user(User.session)
    else
      @notifications = Notification.with_notifiable.unread
                                   .for_subscribed_user(User.session)
    end
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
