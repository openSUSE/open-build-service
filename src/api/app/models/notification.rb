class Notification < ApplicationRecord
  belongs_to :subscriber, polymorphic: true

  serialize :event_payload, Hash

  def event
    @event ||= event_type.constantize.new(event_payload)
  end

  def event_expanded_payload
    event.expanded_payload
  end

  def template_name
    event_type.gsub('Event::', '').underscore
  end

  private

  def parsed_event_payload
    Yajl::Parser.parse(event_payload)
  end

  def event
    event_type.constantize.new(parsed_event_payload.merge(eventtype: event_type))
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
