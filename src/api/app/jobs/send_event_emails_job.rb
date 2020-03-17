class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  EVENTS_TO_NOTIFY = ['Event::RequestStatechange',
                      'Event::RequestCreate',
                      'Event::ReviewWanted',
                      'Event::CommentForProject',
                      'Event::CommentForPackage',
                      'Event::CommentForRequest'].freeze

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
    return {} unless event.eventtype.in?(EVENTS_TO_NOTIFY)

    dynamic_params = { notifiable_id: event.payload['id'], notifiable_type: 'BsRequest', title: notification_title(event.subject) }

    if event.eventtype == 'Event::RequestStatechange'
      return dynamic_params.merge!({ bs_request_state: event.payload['state'], bs_request_oldstate: event.payload['oldstate'] })
    end

    return dynamic_params if event.eventtype == 'Event::RequestCreate'
    return dynamic_params.merge!({ notifiable_type: 'Review' }) if event.eventtype == 'Event::ReviewWanted'

    dynamic_params.merge!({ notifiable_type: 'Comment' })
  end

  def notification_title(subject)
    return subject if subject.size <= 255

    subject.slice(0, 252).concat('...')
  end
end
