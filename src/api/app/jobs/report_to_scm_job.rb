class ReportToSCMJob < ApplicationJob
  queue_as :scm # TODO: Is this fine?

  def perform
    Event::Base.where(eventtype: ['Event::BuildFail', 'Event::BuildSuccess'], mails_sent: false).order(created_at: :asc).limit(1000).each do |event|
      subscribers = event.subscribers
      event.update(mails_sent: true) if subscribers.empty?

      begin
        event.subscriptions(:scm).each do |subscription|
          SCMStatusReporter.new(subscription.payload, subscription.token.scm_token, event).call
        end
      rescue StandardError => e
        Airbrake.notify(e, event_id: event.id)
      ensure
        event.update(mails_sent: true)
      end
    end

    true
  end
end
