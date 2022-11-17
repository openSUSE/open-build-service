class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_for(current_user)
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    # stop_all_streams
  end
end
