class Webui::Users::NotificationsController < Webui::WebuiController
  VALID_NOTIFICATION_TYPES = %i[read reviews comments requests unread incoming_requests outgoing_requests relationships_created relationships_deleted
                                build_failures reports workflow_runs appealed_decisions].freeze

  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  before_action :set_current_user, only: %i[index update]
  before_action :set_selected_filter_for_update, only: :update
  before_action :set_selected_filter_for_read, only: :index
  after_action :verify_policy_scoped

  def index
    @notifications = paginated_notifications
    @show_read_all_button = show_read_all_button?
    @filtered_by = @selected_filter.to_h.filter { |_k, v| v.present? }.keys - %w[unread read]
  end

  def update
    notifications = if @selected_filter[:notification][:update_all]
                      fetch_notifications
                    else
                      fetch_notifications.where(id: @selected_filter[:notification][:id])
                    end
    # rubocop:disable Rails/SkipsModelValidations
    # FIXME: This has room for improvement
    undelivered_notifications_ids = notifications.where(delivered: false).map(&:id)
    delivered_notifications_ids = notifications.where(delivered: true).map(&:id)
    read_count = Notification.where(id: undelivered_notifications_ids).update_all('delivered = !delivered')
    unread_count = Notification.where(id: delivered_notifications_ids).update_all('delivered = !delivered')
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
          selected_filter: @selected_filter,
          show_read_all_button: show_read_all_button?,
          user: User.session
        }
      end
    end
  end

  private

  def set_current_user
    @current_user = User.session
  end

  def show_more(notifications)
    total = notifications.size
    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{Notification::MAX_PER_PAGE} notifications per page." if total > Notification::MAX_PER_PAGE
    notifications.page(params[:page]).per([total, Notification::MAX_PER_PAGE].min)
  end

  def fetch_notifications
    notifications = policy_scope(Notification).for_web.includes(notifiable: [{ commentable: [{ comments: :user }, :project, :bs_request_actions] }, :bs_request_actions, :reviews])

    if params.dig(:notification, :unread).blank? && params.dig(:notification, :read).blank?
      # no read|unread param filters fallback on `unread` notifications only
      notifications = notifications.unread
    elsif params.dig(:notification, :unread) && params.dig(:notification, :read)
      notifications = notifications.unread.or(notifications.read)
    else
      notifications = notifications.unread if params.dig(:notification, :unread)
      notifications = notifications.read if params.dig(:notification, :read)
    end

    relations_type = []
    relations_type << notifications.comments if params.dig(:notification, :comments)
    relations_type << notifications.requests if params.dig(:notification, :requests)
    relations_type << notifications.incoming_requests(User.session) if params.dig(:notification, :incoming_requests)
    relations_type << notifications.outgoing_requests(User.session) if params.dig(:notification, :outgoing_requests)
    relations_type << notifications.relationships_created if params.dig(:notification, :relationships_created)
    relations_type << notifications.relationships_deleted if params.dig(:notification, :relationships_deleted)
    relations_type << notifications.build_failures if params.dig(:notification, :build_failures)
    relations_type << notifications.reports if params.dig(:notification, :reports)
    relations_type << notifications.workflow_runs if params.dig(:notification, :workflow_runs)
    relations_type << notifications.appealed_decisions if params.dig(:notification, :appealed_decisions)
    notifications = notifications.merge(relations_type.inject(:or)) unless relations_type.empty?

    if params.dig(:notification, :project)
      relations_project = (params.dig(:notification, :project).keys || []).map do |project_name, _|
        notifications.for_project(project_name)
      end
      notifications = notifications.merge(relations_project.inject(:or)) unless relations_project.empty?
    end

    if params.dig(:notification, :group)
      relations_group = (params.dig(:notification, :group).keys || []).map do |group_name, _|
        notifications.for_group(group_name)
      end
      notifications = notifications.merge(relations_group.inject(:or)) unless relations_group.empty?
    end

    notifications
  end

  def paginated_notifications
    notifications = fetch_notifications
    params[:page] = notifications.page(@selected_filter[:page]).total_pages if notifications.page(@selected_filter[:page]).out_of_range?
    params[:show_more] ? show_more(notifications) : notifications.page(@selected_filter[:page])
  end

  def show_read_all_button?
    fetch_notifications.count > Notification::MAX_PER_PAGE
  end

  def send_notifications_information_rabbitmq(read_count, unread_count)
    RabbitmqBus.send_to_bus('metrics', "notification,action=read value=#{read_count}") if read_count.positive?
    RabbitmqBus.send_to_bus('metrics', "notification,action=unread value=#{unread_count}") if unread_count.positive?
  end

  def set_selected_filter_for_update
    @selected_filter = { notification: params.require(:notification).permit(VALID_NOTIFICATION_TYPES + [:update_all, { id: [], project: {}, group: {} }]) }
  end

  def set_selected_filter_for_read
    @selected_filter = params.permit(:user_login, notification: [VALID_NOTIFICATION_TYPES + [project: {}, group: {}]]).to_h
    return if params.dig(:notification, :unread) || params.dig(:notification, :read)

    # no read|unread param filters fallback on `unread` notifications only
    @selected_filter['notification'] = {} unless @selected_filter['notification']
    @selected_filter['notification']['unread'] = 1
  end
end
