# TODO: This job is doing much more than sending emails to event subscribers. It's also handling notifications for web and RSS channels.
class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  def perform
    # TODO: mails_sent should be renamed to something like processed
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      # Email channel
      subscribers = event.subscribers
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
    return if subscribers.empty?

    EventMailer.with(subscribers: subscribers, event: event).notification_email.deliver_now
  rescue StandardError => e
    Airbrake.notify(e, event_id: event.id)
  ensure
    event.update(mails_sent: true)
  end
end
