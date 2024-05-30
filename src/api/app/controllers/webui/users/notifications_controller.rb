class Webui::Users::NotificationsController < Webui::WebuiController
  include Webui::NotificationsFilter

  ALLOWED_FILTERS = %w[all comments requests incoming_requests outgoing_requests relationships_created relationships_deleted build_failures
                       reports reviews workflow_runs appealed_decisions].freeze
  ALLOWED_STATES = %w[unread read].freeze

  before_action :require_login
  before_action :set_filter_type, :set_filter_state
  before_action :set_notifications
  before_action :set_notifications_to_be_updated, only: [:update]
  before_action :set_show_read_all_button
  before_action :set_selected_filter
  before_action :paginate_notifications

  def index
    @filtered_project = Project.find_by(name: params[:project])
    @current_user = User.session
  end

  def update
    # rubocop:disable Rails/SkipsModelValidations
    @read_count = Notification.where(id: @undelivered_notification_ids).update_all('delivered = !delivered')
    @unread_count = Notification.where(id: @delivered_notification_ids).update_all('delivered = !delivered')
    # rubocop:enable Rails/SkipsModelValidations

    respond_to do |format|
      format.html { redirect_to my_notifications_path }
      format.js do
        render partial: 'update', locals: {
          notifications: @notifications,
          selected_filter: @selected_filter,
          show_read_all_button: @show_read_all_button,
          user: User.session
        }
      end
      send_notifications_information_rabbitmq(@read_count, @unread_count)
    end
  end

  private

  def set_filter_type
    @filter_type = params[:kind] || 'all'
    raise FilterNotSupportedError if @filter_type.present? && ALLOWED_FILTERS.exclude?(@filter_type)
  end

  def set_filter_state
    @filter_state = params[:state] || 'unread'
    raise FilterNotSupportedError if @filter_state.present? && ALLOWED_STATES.exclude?(@filter_state)
  end

  def set_notifications
    @notifications = User.session!.notifications.for_web.includes(notifiable: [{ commentable: [{ comments: :user }, :project, :bs_request_actions] }, :bs_request_actions, :reviews])
    @notifications = @notifications.for_project_name(params[:project]) if params[:project].present?
    @notifications = @notifications.for_group_title(params[:group]) if params[:group].present?
    @notifications = filter_notifications_by_type(@notifications, @filter_type)
    @notifications = filter_notifications_by_state(@notifications, @filter_state)
  end

  def set_notifications_to_be_updated
    return unless params[:notification_ids]

    @undelivered_notification_ids = @notifications.where(id: params[:notification_ids]).where(delivered: false).map(&:id)
    @delivered_notification_ids = @notifications.where(id: params[:notification_ids]).where(delivered: true).map(&:id)
  end

  def set_show_read_all_button
    @show_read_all_button = @notifications.count > Notification::MAX_PER_PAGE
  end

  def set_selected_filter
    @selected_filter = { kind: @filter_type, state: @filter_state, project: params[:project], group: params[:group] }
  end

  def show_more(notifications)
    total = notifications.size
    per_page = total.positive? ? [total, Notification::MAX_PER_PAGE].min : Kaminari.config.default_per_page

    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{Notification::MAX_PER_PAGE} notifications per page." if total > Notification::MAX_PER_PAGE
    notifications.page(params[:page]).per(per_page)
  end

  def filter_notifications_by_state(notifications, filter_state)
    case filter_state
    when 'read'
      notifications.read
    else
      notifications.unread
    end
  end

  def send_notifications_information_rabbitmq(read_count, unread_count)
    RabbitmqBus.send_to_bus('metrics', "notification,action=read value=#{read_count}") if read_count.positive?
    RabbitmqBus.send_to_bus('metrics', "notification,action=unread value=#{unread_count}") if unread_count.positive?
  end

  def paginate_notifications
    @notifications = params[:show_more] ? show_more(@notifications) : @notifications.page(params[:page])
    params[:page] = @notifications.total_pages if @notifications.out_of_range?
  end
end
