class Webui::Users::NotificationsController < Webui::WebuiController
  VALID_NOTIFICATION_TYPES = ['read', 'reviews', 'comments', 'requests', 'unread', 'incoming_requests', 'outgoing_requests'].freeze

  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  before_action :check_param_type, :check_param_project, only: :index
  before_action :check_feature_toggle

  after_action :verify_policy_scoped

  def index
    @notifications = paginated_notifications
    @show_read_all_button = show_read_all_button?
    @filtered_project = Project.find_by(name: params[:project])
    @selected_filter = selected_filter
  end

  def update
    notifications = if params[:update_all]
                      fetch_notifications
                    else
                      fetch_notifications.where(id: params[:notification_ids])
                    end
    # rubocop:disable Rails/SkipsModelValidations
    unless notifications.update_all('delivered = !delivered')
      flash.now[:error] = "Couldn't mark the notifications as #{notifications.first.unread? ? 'read' : 'unread'}"
    end
    # rubocop:enable Rails/SkipsModelValidations

    respond_to do |format|
      format.html { redirect_to my_notifications_path }
      format.js do
        render partial: 'update', locals: {
          notifications: paginated_notifications,
          selected_filter: selected_filter,
          show_read_all_button: show_read_all_button?
        }
      end
    end
  end

  private

  def selected_filter
    { type: params[:type], project: params[:project], group: params[:group] }
  end

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

  def check_feature_toggle
    feature_enabled?(:notifications_redesign)
  end

  def show_more(notifications)
    total = notifications.size
    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{Notification::MAX_PER_PAGE} notifications per page." if total > Notification::MAX_PER_PAGE
    notifications.page(params[:page]).per([total, Notification::MAX_PER_PAGE].min)
  end

  def fetch_notifications
    notifications_for_subscribed_user = NotificationsFinder.new(policy_scope(Notification).includes(:notifiable))
    if params[:project]
      notifications_for_subscribed_user.for_project_name(params[:project])
    elsif params[:group]
      notifications_for_subscribed_user.for_group_title(params[:group])
    else
      notifications_for_subscribed_user.for_notifiable_type(params[:type])
    end
  end

  def paginated_notifications
    notifications = fetch_notifications
    params[:page] = notifications.page(params[:page]).total_pages if notifications.page(params[:page]).out_of_range?
    params[:show_more] ? show_more(notifications) : notifications.page(params[:page])
  end

  def show_read_all_button?
    fetch_notifications.count > Notification::MAX_PER_PAGE
  end
end
