class Webui::Users::NotificationsController < Webui::WebuiController
  include Webui::NotificationsFilter

  ALLOWED_FILTERS = %w[all comments requests incoming_requests outgoing_requests relationships_created relationships_deleted build_failures
                       reports reviews workflow_runs appealed_decisions].freeze
  ALLOWED_STATES = %w[all unread read].freeze

  before_action :require_login
  before_action :set_filter_kind, :set_filter_state, :set_filter_project, :set_filter_group
  before_action :set_notifications
  before_action :set_notifications_to_be_updated, only: :update
  before_action :set_counted_notifications, only: :index
  before_action :filter_notifications, only: :index
  before_action :set_show_read_all_button, only: :index
  before_action :set_selected_filter
  before_action :paginate_notifications, only: :index

  skip_before_action :set_unread_notifications_count, only: :update

  def index; end

  def update
    # The button value specifies whether we selected read or unread
    deliver = params[:button] == 'read'
    # rubocop:disable Rails/SkipsModelValidations
    @count = @notifications.where(id: @notification_ids, delivered: !deliver).update_all(delivered: deliver)
    # rubocop:enable Rails/SkipsModelValidations

    # manually update the count and the filtered subset after the update
    set_unread_notifications_count # before_action filter method defined in the Webui controller
    set_counted_notifications
    filter_notifications
    set_show_read_all_button
    paginate_notifications

    respond_to do |format|
      format.html { redirect_to my_notifications_path }
      format.js do
        render partial: 'update', locals: {
          notifications: @notifications,
          unread_notifications_count: @unread_notifications_count,
          selected_filter: @selected_filter,
          counted_notifications: @counted_notifications,
          show_read_all_button: @show_read_all_button,
          user: User.session
        }
      end
      send_notifications_information_rabbitmq(deliver, @count)
    end
  end

  private

  def set_filter_kind
    @filter_kind = Array(params[:kind].presence || 'all') # in case just one value, we want an array anyway
    raise FilterNotSupportedError unless (@filter_kind - ALLOWED_FILTERS).empty?
  end

  def set_filter_state
    @filter_state = params[:state].presence || 'unread'
    raise FilterNotSupportedError if ALLOWED_STATES.exclude?(@filter_state)
  end

  def set_filter_project
    @filter_project = params[:project] || []
  end

  def set_filter_group
    @filter_group = params[:group] || []
  end

  def set_notifications
    @notifications = User.session!.notifications.for_web.includes(notifiable: [{ commentable: [{ comments: :user }, :project, :bs_request_actions] }, :bs_request_actions, :reviews])
  end

  def set_counted_notifications
    @counted_notifications = {}
    @counted_notifications['all'] = @notifications.count
    @counted_notifications['unread'] = @unread_notifications_count # Variable set in the Webui controller
    @counted_notifications['read'] = @counted_notifications['all'] - @counted_notifications['unread']
    @counted_notifications['comments'] = @notifications.for_comments.count
    @counted_notifications['requests'] = @notifications.for_requests.count
    @counted_notifications['incoming_requests'] = @notifications.for_incoming_requests(User.session).count
    @counted_notifications['outgoing_requests'] = @notifications.for_outgoing_requests(User.session).count
    @counted_notifications['relationships_created'] = @notifications.for_relationships_created.count
    @counted_notifications['relationships_deleted'] = @notifications.for_relationships_deleted.count
    @counted_notifications['build_failures'] = @notifications.for_build_failures.count
    @counted_notifications['reports'] = @notifications.for_reports.count
    @counted_notifications['workflow_runs'] = @notifications.for_workflow_runs.count
    @counted_notifications['appealed_decisions'] = @notifications.for_appealed_decisions.count
  end

  def update_counted_notifications
    @counted_notifications['unread'] = User.session.unread_notifications_count
    @counted_notifications['read'] = @counted_notifications['all'].to_i - @counted_notifications['unread']
  end

  def filter_notifications
    @notifications = filter_notifications_by_project(@notifications, @filter_project)
    @notifications = filter_notifications_by_group(@notifications, @filter_group)
    @notifications = filter_notifications_by_state(@notifications, @filter_state)
    @notifications = filter_notifications_by_kind(@notifications, @filter_kind)
  end

  def set_notifications_to_be_updated
    @notification_ids = []

    if params[:update_all]
      filter_notifications
      @notification_ids = @notifications.map(&:id)
    elsif params[:notification_ids]
      @notification_ids = @notifications.where(id: params[:notification_ids]).map(&:id)
    end
  end

  def set_show_read_all_button
    @show_read_all_button = @counted_notifications['all'] > Notification::MAX_PER_PAGE
  end

  def set_selected_filter
    @selected_filter = { kind: @filter_kind, state: @filter_state, project: @filter_project, group: @filter_group }
    @filtered_by_text = "State: #{@filter_state.to_s.humanize} - Type: #{@filter_kind.map { |s| s.to_s.humanize }.join(', ')}"

    @projects_for_filter = ProjectsForFilterFinder.new.call
    @groups_for_filter = GroupsForFilterFinder.new.call
  end

  def show_more(notifications)
    total = @counted_notifications['all']
    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{Notification::MAX_PER_PAGE} notifications per page." if total > Notification::MAX_PER_PAGE
    notifications.page(params[:page]).per([total, Notification::MAX_PER_PAGE].min)
  end

  def send_notifications_information_rabbitmq(delivered, count)
    action = delivered ? 'read' : 'unread'
    RabbitmqBus.send_to_bus('metrics', "notification,action=#{action} value=#{count}") if count.positive?
  end

  def paginate_notifications
    @notifications = params[:show_more] ? show_more(@notifications) : @notifications.page(params[:page])
    params[:page] = @notifications.total_pages if @notifications.out_of_range?
  end
end
