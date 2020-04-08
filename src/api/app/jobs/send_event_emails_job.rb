class SendEventEmailsJob < ApplicationJob
  queue_as :mailers

  def perform
    Event::Base.where(mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      subscribers = event.subscribers

      if subscribers.empty?
        event.update_attributes(mails_sent: true)
        next
      end

      NotificationCreator.new(event).call
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
end
