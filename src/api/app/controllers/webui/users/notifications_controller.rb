class Webui::Users::NotificationsController < Webui::WebuiController
  VALID_NOTIFICATION_TYPES = %i[read reviews comments requests unread incoming_requests outgoing_requests relationships_created relationships_deleted
                                build_failures reports workflow_runs appealed_decisions].freeze

  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  before_action :set_current_user, only: %i[index update]
  after_action :verify_policy_scoped

  def index
    @selected_filter = params.permit(:user_login, notification: [VALID_NOTIFICATION_TYPES + [project: {}, group: {}]])
    @notifications = paginated_notifications
    @show_read_all_button = show_read_all_button?
    @filtered_by = @selected_filter.to_h.filter { |_k, v| v.present? }.keys - %w[unread read]
  end

  def update
    notification_ids = notification_params
    @selected_filter = { notification: notification_params }
    notifications = if notification_ids[:update_all]
                      fetch_notifications
                    else
                      fetch_notifications.where(id: notification_ids[:id])
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

  def notification_params
    params.require(:notification).permit(VALID_NOTIFICATION_TYPES + [:update_all, { id: [], project: {}, group: {} }])
  end

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

    relations = notifications
    if params.dig(:notification, :unread).blank? && params.dig(:notification, :read).blank?
      # no read|unread param filters fallback on `unread` notifications only
      @selected_filter['unread'] = 1
      relations = notifications.unread
    elsif params.dig(:notification, :unread) && params.dig(:notification, :read)
      relations = notifications.unread.or(notifications.read)
    else
      relations = notifications.unread if params.dig(:notification, :unread)
      relations = notifications.read if params.dig(:notification, :read)
    end

    relations_type = []
    relations_type << relations.comments if params.dig(:notification, :comments)
    relations_type << relations.requests if params.dig(:notification, :requests)
    relations_type << relations.incoming_requests(User.session) if params.dig(:notification, :incoming_requests)
    relations_type << relations.outgoing_requests(User.session) if params.dig(:notification, :outgoing_requests)
    relations_type << relations.relationships_created if params.dig(:notification, :relationships_created)
    relations_type << relations.relationships_deleted if params.dig(:notification, :relationships_deleted)
    relations_type << relations.build_failures if params.dig(:notification, :build_failures)
    relations_type << relations.reports if params.dig(:notification, :reports)
    relations_type << relations.workflow_runs if params.dig(:notification, :workflow_runs)
    relations_type << relations.appealed_decisions if params.dig(:notification, :appealed_decisions)
    relations = relations.merge(relations_type.inject(:or)) unless relations_type.empty?

    if params.dig(:notification, :project)
      relations_project = (params.dig(:notification, :project).keys || []).map do |project_name, _|
        relations.for_project(project_name)
      end
      relations = relations.merge(relations_project.inject(:or)) unless relations_project.empty?
    end

    if params.dig(:notification, :group)
      relations_group = (params.dig(:notification, :group).keys || []).map do |group_name, _|
        relations.for_group(group_name)
      end
      relations = relations.merge(relations_group.inject(:or)) unless relations_group.empty?
    end

    relations
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
end
