class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  def perform
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      subscribers = event.subscribers

      if subscribers.empty?
        event.update_attributes(mails_sent: true)
        next
      end

      begin
        create_rss_notifications(event)
        EventMailer.event(subscribers, event).deliver_now
      rescue StandardError => e
        Airbrake.notify(e, event_id: event.id)
      ensure
        event.update_attributes(mails_sent: true)
      end
    end
    true
  end

  private

  def create_rss_notifications(event)
    event.subscriptions.each do |subscription|
      notification_params = {
        subscriber: subscription.subscriber,
        event_type: event.eventtype,
        event_payload: event.payload,
        subscription_receiver_role: subscription.receiver_role
      }

      next if subscription.subscriber && subscription.subscriber.away?
      Notification::RssFeedItem.create(notification_params.merge!(notification_dynamic_params(event)))
    end
  end

  def notification_dynamic_params(event)
    if event.eventtype == 'RequestStatechange'
      return {
        notifiable_type: 'BsRequest',
        notifiable_id: event.payload['id'],
        bs_request_state: event.payload['state'],
        bs_request_oldstate: event.payload['oldstate']
      }
    end

    if event.eventtype.in?(['ReviewWanted', 'RequestCreate'])
      return {
        notifiable_type: 'BsRequest',
        notifiable_id: event.payload['id']
      }
    end

    if event.eventtype.in?(['CommentForProject', 'CommentForPackage', 'CommentForRequest'])
      return {
        notifiable_type: 'Comment',
        notifiable_id: event.payload['id']
      }
    end

    {}
  end
end
