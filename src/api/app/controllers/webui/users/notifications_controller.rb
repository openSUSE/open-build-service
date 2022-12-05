class Webui::Users::NotificationsController < Webui::WebuiController
  VALID_NOTIFICATION_TYPES = ['read', 'reviews', 'comments', 'requests', 'unread', 'incoming_requests', 'outgoing_requests', 'relationships_created', 'relationships_deleted',
                              'build_failures'].freeze

  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  before_action :check_param_type, :check_param_project, only: :index

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
    read_count = notifications.where(delivered: false).update_all('delivered = !delivered')
    unread_count = notifications.where(delivered: true).update_all('delivered = !delivered')
    # rubocop:enable Rails/SkipsModelValidations

    if read_count.zero? && unread_count.zero?
      flash.now[:error] = "Couldn't update the notifications"
    else
      send_notifications_information_rabbitmq(read_count, unread_count)
    end

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

  def show_more(notifications)
    total = notifications.size
    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{Notification::MAX_PER_PAGE} notifications per page." if total > Notification::MAX_PER_PAGE
    notifications.page(params[:page]).per([total, Notification::MAX_PER_PAGE].min)
  end

  def fetch_notifications
    notifications = policy_scope(Notification).for_web.includes(notifiable: [{ commentable: [{ comments: :user }, :project, :bs_request_actions] }, :bs_request_actions, :reviews])
    notifications_finder = NotificationsFinder.new(notifications)

    if params[:project]
      notifications_finder.for_project_name(params[:project])
    elsif params[:group]
      notifications_finder.for_group_title(params[:group])
    else
      notifications_finder.for_notifiable_type(params[:type])
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

  def send_notifications_information_rabbitmq(read_count, unread_count)
    RabbitmqBus.send_to_bus('metrics', "notification,action=read value=#{read_count}") if read_count.positive?
    RabbitmqBus.send_to_bus('metrics', "notification,action=unread value=#{unread_count}") if unread_count.positive?
  end
end
