class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true

  serialize :event_payload, JSON

  def initialize(params = {})
    super
    shorten_payload_if_necessary
  end

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  private

  def shorten_payload_if_necessary
    return if event.shortenable_key.nil? # If no shortenable_key is set then we cannot shorten the payload

    # NOTE: ActiveSupport::JSON is used for serializing ActiveRecord models attributes
    overflow_bytes = ActiveSupport::JSON.encode(event_payload).bytesize - 65535

    return if overflow_bytes <= 0

    # Shorten the payload so it will fit into the database column
    shortenable_content = event_payload[event.shortenable_key.to_s]
    new_size = shortenable_content.bytesize - overflow_bytes
    event_payload[event.shortenable_key.to_s] = shortenable_content.mb_chars.limit(new_size)
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                         :integer          not null, primary key
#  type                       :string(255)      not null
#  event_type                 :string(255)      not null
#  event_payload              :text(65535)      not null
#  subscription_receiver_role :string(255)      not null
#  delivered                  :boolean          default(FALSE)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  subscriber_type            :string(255)      indexed => [subscriber_id]
#  subscriber_id              :integer          indexed => [subscriber_type]
#
# Indexes
#
#  index_notifications_on_subscriber_type_and_subscriber_id  (subscriber_type,subscriber_id)
#
