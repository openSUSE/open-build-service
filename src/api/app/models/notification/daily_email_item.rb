class Notification::DailyEmailItem < Notification
  def self.cleanup
    where(delivered: true).delete_all
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
