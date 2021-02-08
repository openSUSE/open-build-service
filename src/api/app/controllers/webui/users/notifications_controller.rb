class Webui::Users::NotificationsController < Webui::WebuiController
  MAX_PER_PAGE = 300
  VALID_NOTIFICATION_TYPES = ['read', 'reviews', 'comments', 'requests', 'unread', 'incoming_requests', 'outgoing_requests'].freeze

  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth
  before_action :check_param_type, :check_param_project, only: :index
  before_action :check_feature_toggle

  after_action :verify_policy_scoped

  def index
    @notifications = paginated_notifications
    @filtered_project = Project.find_by(name: params[:project])
    @notifications_filter = notifications_filter
  end

  def update
    notifications = fetch_notifications.where(id: params[:notification_ids])

    # rubocop:disable Rails/SkipsModelValidations
    unless notifications.update_all('delivered = !delivered')
      flash.now[:error] = "Couldn't mark the notifications as #{notifications.first.unread? ? 'read' : 'unread'}"
    end
    # rubocop:enable Rails/SkipsModelValidations

    respond_to do |format|
      format.html { redirect_to my_notifications_path }
      format.js do
        render partial: 'update', locals: {
          notifications: paginated_notifications,
          notifications_filter: notifications_filter
        }
      end
    end
  end

  private

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

  def check_feature_toggle
    feature_enabled?(:notifications_redesign)
  end

  def show_all(notifications)
    total = notifications.size
    flash.now[:info] = "You have too many notifications. Displaying a maximum of #{MAX_PER_PAGE} notifications per page." if total > MAX_PER_PAGE
    notifications.page(params[:page]).per([total, MAX_PER_PAGE].min)
  end

  # Returns a hash where the key is the name of the project and the value is the amount of notifications
  # associated to that project. The hash is sorted by amount and then name.
  def projects_for_filter
    Project.joins(:notifications)
           .where(notifications: { subscriber: User.session, delivered: false, web: true })
           .order('name desc').group(:name).count # this query returns a sorted-by-name hash like { "home:b" => 1, "home:a" => 3  }
           .sort_by(&:last).reverse.to_h # this sorts the hash by amount: { "home:a" => 3, "home:b" => 1 }
  end

  def notifications_count
    finder = NotificationsFinder.new(User.session.notifications.for_web)
    counted_notifications = finder.unread.group(:notifiable_type).count
    counted_notifications['incoming_requests'] = finder.for_incoming_requests.count
    counted_notifications['outgoing_requests'] = finder.for_outgoing_requests.count
    counted_notifications.merge!('unread' => User.session.unread_notifications)
  end

  def fetch_notifications
    notifications_for_subscribed_user = NotificationsFinder.new(policy_scope(Notification))
    if params[:project]
      notifications_for_subscribed_user.for_project_name(params[:project])
    else
      notifications_for_subscribed_user.for_notifiable_type(params[:type])
    end
  end

  def paginated_notifications
    notifications = fetch_notifications
    params[:page] = notifications.page(params[:page]).total_pages if notifications.page(params[:page]).out_of_range?
    params[:show_all] ? show_all(notifications) : notifications.page(params[:page])
  end

  def notifications_filter
    NotificationsFilterPresenter.new(projects_for_filter,
                                     notifications_count,
                                     params[:type],
                                     params[:project])
  end
end
