class Notification::RssFeedItem < Notification
  MAX_ITEMS_PER_USER = 10
  MAX_ITEMS_PER_GROUP = 10

  def self.cleanup
    User.all_without_nobody.find_in_batches(batch_size: 500) do |batch|
      batch.each do |user|
        offset = user.is_active? ? MAX_ITEMS_PER_USER : 0
        ids = user.rss_feed_items.offset(offset).pluck(:id)
        user.rss_feed_items.where(id: ids).delete_all
      end
    end
    Group.find_in_batches(batch_size: 500) do |batch|
      batch.each do |group|
        ids = group.rss_feed_items.offset(MAX_ITEMS_PER_GROUP).pluck(:id)
        group.rss_feed_items.where(id: ids).delete_all
      end
    end
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
