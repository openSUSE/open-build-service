# TODO: This job is doing much more than sending emails to event subscribers. It's also handling notifications for web and RSS channels.
class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  def perform
    # TODO: mails_sent should be renamed to something like processed
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      # Email channel
      subscribers = event_subscribers(event: event)
      event.update(mails_sent: true) if subscribers.empty?

      # Web and RSS channels
      NotificationService::Notifier.new(event).call

      # Email channel again...
      send_email(subscribers, event)
    end
    true
  end

  private

  def send_email(subscribers, event)
    return if event.involves_hidden_project?
    return if subscribers.empty?

    email = EventMailer.with(subscribers: subscribers, event: event).notification_email
    email.deliver_now
  rescue StandardError => e
    Airbrake.notify(e, event_id: event.id, email: email.inspect)
  ensure
    event.update(mails_sent: true)
  end

  def event_subscribers(event:)
    if event.is_a?(Event::Report)
      event.subscribers.select { |subscriber| ReportPolicy.new(subscriber, Report).notify? }
    else
      event.subscribers
    end
  end
end
