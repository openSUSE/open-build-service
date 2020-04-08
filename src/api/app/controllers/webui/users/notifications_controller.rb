class Webui::Users::NotificationsController < Webui::WebuiController
  MAX_PER_PAGE = 300
  VALID_NOTIFICATION_TYPES = ['read', 'reviews', 'comments', 'requests', 'unread'].freeze

  before_action :require_login
  before_action :check_param_type, :check_param_project, only: :index

  def index
    notifications_for_subscribed_user = NotificationsFinder.new.for_subscribed_user

    @projects = NotificationProjects.new(NotificationsFinder.new(notifications_for_subscribed_user).for_notifiable_type('unread')).call

    @notifications = if params[:project]
                       NotificationsFinder.new(notifications_for_subscribed_user).for_project_name(params[:project])
                     else
                       NotificationsFinder.new(notifications_for_subscribed_user).for_notifiable_type(params[:type])
                     end
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

  def check_param_type
    return if params[:type].nil? || VALID_NOTIFICATION_TYPES.include?(params[:type])

    flash[:error] = 'Filter not valid.'
    redirect_to my_notifications_path
  end

  def check_param_project
    return unless params[:project] == ''

    flash[:error] = 'Filter not valid.'
    redirect_to my_notifications_path
  end

  def show_all
    total = @notifications.size
    if total > MAX_PER_PAGE
      flash.now[:info] = "You have too many notifications. Displaying a maximum of #{MAX_PER_PAGE} notifications per page."
    end
    @notifications = @notifications.page(params[:page]).per([total, MAX_PER_PAGE].min)
  end
end
