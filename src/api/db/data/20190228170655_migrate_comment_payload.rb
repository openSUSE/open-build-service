class MigrateCommentPayload < ActiveRecord::Migration[5.2]
  def up
    Event::CommentForPackage.all.find_each { |event| convert_payload(event) }
    Event::CommentForProject.all.find_each { |event| convert_payload(event) }
    Event::CommentForRequest.all.find_each { |event| convert_payload(event) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def convert_payload(event)
    payload = event.payload
    # Find unconverted comment events
    return unless integer?(payload['commenter'])

    payload[:commenter] = User.find(event.payload['commenter']).login
    payload[:commenters] = User.find(event.payload['commenters']).pluck(:login)
    event.set_payload(payload, payload.keys)
    event.save!
  end

  def integer?(string)
    # rubocop:disable Style/RescueModifier
    Integer(string) rescue false
    # rubocop:enable Style/RescueModifier
  end
end
