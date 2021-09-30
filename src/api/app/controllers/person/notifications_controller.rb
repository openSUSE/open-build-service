module Person
  class NotificationsController < ApplicationController
    MAX_PER_PAGE = 300

    # GET /my/notifications
    def index
      @notifications = paginated_notifications
      @notifications_total = @notifications.count
    end

    def show_all(notifications)
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
      NotificationsFinder.new(filtered_notifications).for_notifiable_type('requests')
    end

    def paginated_notifications
      notifications = fetch_notifications
      params[:page] = notifications.page(params[:page]).total_pages if notifications.page(params[:page]).out_of_range?
      params[:show_all] ? show_all(notifications) : notifications.page(params[:page])
    end
  end
end
