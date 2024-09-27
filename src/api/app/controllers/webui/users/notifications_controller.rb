class Webui::Users::NotificationsController < Webui::WebuiController
  include Webui::NotificationsFilter

  ALLOWED_FILTERS = %w[all comments requests incoming_requests outgoing_requests relationships_created relationships_deleted build_failures
                       reports reviews workflow_runs appealed_decisions member_on_groups].freeze
  ALLOWED_STATES = %w[all unread read].freeze
  ALLOWED_REPORT_FILTERS = %w[with_decision without_decision reportable_type].freeze

  before_action :require_login
  before_action :set_filter_kind, :set_filter_state, :set_filter_report_decision, :set_filter_reportable_type,
                :set_filter_project, :set_filter_group, :set_filter_request_state
  before_action :set_notifications
  before_action :set_notifications_to_be_updated, only: :update
  before_action :set_counted_notifications, only: :index
  before_action :filter_notifications, only: :index
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
    paginate_notifications

    respond_to do |format|
      format.html { redirect_to my_notifications_path }
      format.js do
        render partial: 'update', locals: {
          notifications: @notifications,
          unread_notifications_count: @unread_notifications_count,
          selected_filter: @selected_filter,
          counted_notifications: @counted_notifications,
          user: User.session
        }
      end
      send_notifications_information_rabbitmq(deliver, @count)
    end
  end

  private

  def set_filter_kind
    @filter_kind = Array(params[:kind].presence || 'all')
    @filter_kind.reject! { |kind| ALLOWED_FILTERS.exclude?(kind) }
  end

  def set_filter_state
    @filter_state = params[:state].presence || 'unread'
    @filter_state = 'unread' if ALLOWED_STATES.exclude?(@filter_state)
  end

  def set_filter_report_decision
    @filter_report_decision = params[:report].presence || []
    @filter_report_decision.reject! { |report_filter| ALLOWED_REPORT_FILTERS.exclude?(report_filter) }
  end

  def set_filter_reportable_type
    @filter_reportable_type = params[:reportable_type].presence || []
    @filter_reportable_type = @filter_reportable_type.intersection(Report::REPORTABLE_TYPES.map(&:to_s))
  end

  def set_filter_project
    @filter_project = params[:project] || []
    @projects_for_filter = ProjectsForFilterFinder.new.call
  end

  def set_filter_group
    @filter_group = params[:group] || []
    @groups_for_filter = GroupsForFilterFinder.new.call
  end

  def set_filter_request_state
    @filter_request_state = params[:request_state].presence || []
    @filter_request_state = @filter_request_state.intersection(BsRequest::VALID_REQUEST_STATES.map(&:to_s))
  end

  def set_notifications
    @notifications = User.session.notifications.for_web.includes(notifiable: [{ commentable: [{ comments: :user }, :project, :bs_request_actions] }, :bs_request_actions, :reviews])
  end

  def set_counted_notifications
    @counted_notifications = {}
    @counted_notifications['all'] = @notifications.count
    @counted_notifications['unread'] = @unread_notifications_count # Variable set in the Webui controller
    @counted_notifications['comments'] = @notifications.unread.for_comments.count
    @counted_notifications['requests'] = @notifications.unread.for_requests.count
    @counted_notifications['incoming_requests'] = @notifications.unread.for_incoming_requests(User.session).count
    @counted_notifications['outgoing_requests'] = @notifications.unread.for_outgoing_requests(User.session).count
    @counted_notifications['relationships_created'] = @notifications.unread.for_relationships_created.count
    @counted_notifications['relationships_deleted'] = @notifications.unread.for_relationships_deleted.count
    @counted_notifications['build_failures'] = @notifications.unread.for_build_failures.count
    @counted_notifications['reports'] = @notifications.unread.for_reports.count
    @counted_notifications['workflow_runs'] = @notifications.unread.for_workflow_runs.count
    @counted_notifications['appealed_decisions'] = @notifications.unread.for_appealed_decisions.count
    @counted_notifications['member_on_groups'] = @notifications.unread.for_member_on_groups.count
  end

  def filter_notifications
    @notifications = filter_notifications_by_project(@notifications, @filter_project)
    @notifications = filter_notifications_by_group(@notifications, @filter_group)
    @notifications = filter_notifications_by_state(@notifications, @filter_state)
    @notifications = filter_notifications_by_kind(@notifications, @filter_kind)
    @notifications = filter_notifications_by_request_state(@notifications, @filter_request_state)
    @notifications = filter_notifications_by_report_decision(@notifications, @filter_report_decision)
    @notifications = filter_notifications_by_reportable_type(@notifications, @filter_reportable_type)
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

  def set_selected_filter
    @selected_filter = { kind: @filter_kind,
                         state: @filter_state,
                         report: @filter_report_decision,
                         project: @filter_project,
                         group: @filter_group,
                         request_state: @filter_request_state,
                         reportable_type: @filter_reportable_type }
  end

  def send_notifications_information_rabbitmq(delivered, count)
    action = delivered ? 'read' : 'unread'
    RabbitmqBus.send_to_bus('metrics', "notification,action=#{action} value=#{count}") if count.positive?
  end

  def paginate_notifications
    @notifications = @notifications.page(params[:page]).per(params[:page_size])
  end
end
