class Notifications::Base < ApplicationRecord
  self.table_name = "notifications"

  belongs_to :subscriber, polymorphic: true

  serialize :event_payload, Hash

  def event
    @event ||= event_type.constantize.new(event_payload)
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                         :integer          not null, primary key
#  user_id                    :integer          indexed
#  group_id                   :integer          indexed
#  type                       :string(255)      not null
#  event_type                 :string(255)      not null
#  event_payload              :text(65535)      not null
#  subscription_receiver_role :string(255)      not null
#  delivered                  :boolean          default(FALSE)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_notifications_on_group_id  (group_id)
#  index_notifications_on_user_id   (user_id)
#
