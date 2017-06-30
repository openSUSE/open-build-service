# TODO: Rename this to something more appropriate like "ProcessEvents"
class SendEventEmails
  # we don't need this outside of the migration - but we need to be able
  # to load old jobs from the database (and mark their events) before deleting
  # (see 20151030130011_mark_events)
  attr_accessor :event

  def perform
    Event::Base.where(mails_sent: false).order(:created_at).limit(1000).each do |event|
      event.mails_sent = true
      begin
        event.save!
      rescue ActiveRecord::StaleObjectError
        # if someone else saved it too, better don't continue - we're not alone
        next
      end
      subscribers = event.subscribers
      next if subscribers.empty?

      EventMailer.event(subscribers, event).deliver_now

      create_rss_notifications(event)
      event.create_project_log_entry if event.needs_logging?
    end
    true
  end

  private

  def create_rss_notifications(event)
    event.subscriptions.each do |subscription|
      Notification::RssFeedItem.create(
        subscriber: subscription.subscriber,
        event_type: event.eventtype,
        event_payload: event.payload,
        subscription_receiver_role: subscription.receiver_role
      )
    end
  end

  def needs_logging?(event)
    !event.project_logged && (event.class < Event::Project || event.class < Event::Package)
  end

  def create_project_log_entry(event)
    ProjectLogEntry.create_from(event)
    event.update_attributes(project_logged: true)
  end
end
