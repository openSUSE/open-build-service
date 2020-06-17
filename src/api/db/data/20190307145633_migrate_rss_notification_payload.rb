class MigrateRssNotificationPayload < ActiveRecord::Migration[5.2]
  def up
    Notification.all.find_each { |notification| convert_payload(notification) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def convert_payload(notification)
    return unless notification.event_type.in?(['Event::CommentForPackage', 'Event::CommentForProject', 'Event::CommentForRequest'])

    payload = notification.event_payload
    # Find unconverted comment events
    return unless integer?(payload['commenter'])

    payload['commenter'] = User.find(notification.event_payload['commenter']).login
    payload['commenters'] = User.find(notification.event_payload['commenters']).pluck(:login)
    notification.event_payload = payload
    notification.save!
  end

  def integer?(string)
    # rubocop:disable Style/RescueModifier
    Integer(string) rescue false
    # rubocop:enable Style/RescueModifier
  end
end
