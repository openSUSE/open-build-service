module Person
  class NotificationsController < ApplicationController
    include Person::Errors

    MAX_PER_PAGE = 300
    ALLOWED_FILTERS = ['requests', 'incoming_requests', 'outgoing_requests'].freeze

    before_action :check_feature_toggle
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
      notifications_for_subscribed_user = NotificationsFinder.new(policy_scope(Notification))

      filtered_notifications = if params[:project]
                                 notifications_for_subscribed_user.for_project_name(params[:project])
                               else
                                 notifications_for_subscribed_user.for_subscribed_user
                               end
      # We are limiting it just for BsRequests
      NotificationsFinder.new(filtered_notifications).for_notifiable_type(@filter_type)
    end

    def paginated_notifications
      notifications = fetch_notifications
      params[:page] = notifications.page(params[:page]).total_pages if notifications.page(params[:page]).out_of_range?
      params[:show_maximum] ? show_maximum(notifications) : notifications.page(params[:page])
    end

    # The 'requests' type will be the default value unless another allowed
    # filter is specified in the URL. I.e. "?notifications_type=incoming_requests"
    def check_filter_type
      @filter_type = params.fetch(:notifications_type, 'requests')
      raise FilterNotSupportedError unless ALLOWED_FILTERS.include?(@filter_type)
    end

    def check_feature_toggle
      raise NotFoundError unless Flipper.enabled?(:notifications_redesign, User.session)
    end
  end
end
