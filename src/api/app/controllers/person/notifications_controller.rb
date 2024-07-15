module Person
  class NotificationsController < ApplicationController
    include Person::Errors
    include Webui::NotificationsFilter

    ALLOWED_FILTERS = %w[all comments requests incoming_requests outgoing_requests relationships_created relationships_deleted build_failures
                         reports reviews workflow_runs appealed_decisions member_on_groups].freeze
    ALLOWED_STATES = %w[unread read].freeze

    before_action :set_filter_kind, only: :index
    before_action :set_filter_state, only: :index
    before_action :set_notifications, only: :index
    before_action :set_notification, only: :update

    # GET /my/notifications
    def index
      @notifications_count = @notifications.count
      @paged_notifications = @notifications.page(params[:page])

      params[:page] = @paged_notifications.total_pages if @paged_notifications.out_of_range?
      params[:show_maximum] ? show_maximum(@notifications) : @paged_notifications
    end

    def update
      authorize @notification

      if @notification.toggle(:delivered).save
        render_ok
      else
        render_error(message: @notification.errors.full_messages.to_sentence, status: 400)
      end
    end

    private

    def set_notifications
      @notifications = User.session.notifications
      @notifications = @notifications.for_project_name(params[:project]) if params[:project]
      @notifications = @notifications.for_group_title(params[:group]) if params[:group]
      @notifications = filter_notifications_by_kind(@notifications, @filter_kind)
      @notifications = filter_notifications_by_state(@notifications, @filter_state)
    end

    def set_notification
      @notification = User.session.notifications.find(params[:id])
    end

    def filter_notifications_by_state(notifications, filter_state)
      case filter_state
      when 'read'
        notifications.read
      else
        notifications.unread
      end
    end

    def show_maximum(notifications)
      total = notifications.size
      notifications.page(params[:page]).per([total, Notification.max_per_page].min)
    end

    def set_filter_kind
      @filter_kind = params[:kind] || 'all'
      raise FilterNotSupportedError if @filter_kind.present? && ALLOWED_FILTERS.exclude?(@filter_kind)
    end

    def set_filter_state
      @filter_state = params[:state] || 'unread'
      raise FilterNotSupportedError if @filter_state.present? && ALLOWED_STATES.exclude?(@filter_state)
    end
  end
end
