class NotificationComponent < ApplicationComponent
  def initialize(notification:, selected_filter:)
    super

    @notification = notification
    @selected_filter = selected_filter
  end
end
