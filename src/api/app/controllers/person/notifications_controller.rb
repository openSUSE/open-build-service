module Person
  class NotificationsController < ApplicationController
    include Person::Errors

    MAX_PER_PAGE = 300
    ALLOWED_FILTERS = %w[requests unread incoming_requests outgoing_requests read].freeze

    before_action :check_filter_type, except: [:update]

    # GET /my/notifications
    def index
      @notifications = paginated_notifications
      @notifications_count = @notifications.count
    end

    def update
      notification = authorize Notification.find(params[:id])

      notification.toggle(:delivered).save!

      render_ok
    end

    private

    def show_maximum(notifications)
      total = notifications.size
      notifications.page(params[:page]).per([total, MAX_PER_PAGE].min)
    end

    def fetch_notifications
      notifications = policy_scope(Notification)

      filtered_notifications = if params[:project]
                                 notifications.for_project(params[:project])
                               else
                                 notifications
                               end
      # We are limiting it just for BsRequests
      # This is already filtered, so it's safe to call the scopes dynamically
      filtered_notifications.send(@filter_type)
    end

    def paginated_notifications
      notifications = fetch_notifications
      params[:page] = notifications.page(params[:page]).total_pages if notifications.page(params[:page]).out_of_range?
      params[:show_maximum] ? show_maximum(notifications) : notifications.page(params[:page])
    end

    def check_filter_type
      @filter_type = params[:notifications_type] || 'unread'
      raise FilterNotSupportedError if @filter_type.present? && ALLOWED_FILTERS.exclude?(@filter_type)
    end
  end
end
