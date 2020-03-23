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

      create_notifications(event)
      send_email(subscribers, event)
    end
    true
  end

  private

  def send_email(subscribers, event)
    EventMailer.event(subscribers, event).deliver_now
  rescue StandardError => e
    Airbrake.notify(e, event_id: event.id)
  ensure
    event.update_attributes(mails_sent: true)
  end

  def create_notifications(event)
    return unless event.eventtype.in?(EVENTS_TO_NOTIFY)

    event.subscriptions.each do |subscription|
      create_rss_notification(event, subscription)
    end
  end

  def create_rss_notification(event, subscription)
    return if subscription.subscriber && subscription.subscriber.away?

    notification_params = {
      subscriber: subscription.subscriber,
      event_type: event.eventtype,
      event_payload: event.payload,
      subscription_receiver_role: subscription.receiver_role
    }

    Notification::RssFeedItem.create(notification_params.merge!(notification_dynamic_params(event)))
  rescue StandardError => e
    Airbrake.notify(e, event_id: event.id)
  end

  def notification_dynamic_params(event)
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
