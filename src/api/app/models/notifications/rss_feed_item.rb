class Notifications::RssFeedItem < Notifications::Base
  MAX_ITEMS_PER_USER = 10
  MAX_ITEMS_PER_GROUP = 10

  def self.cleanup
    User.all_without_nobody.find_in_batches batch_size: 500 do |batch|
      batch.each do |user|
        if user.is_active?
          ids = user.rss_feed_items.pluck(:id).slice(MAX_ITEMS_PER_USER..-1)
          user.rss_feed_items.where(id: ids).delete_all
        else
          user.rss_feed_items.delete_all
        end
      end
    end
    Group.find_in_batches batch_size: 500 do |batch|
      batch.each do |group|
        ids = group.rss_feed_items.pluck(:id).slice(MAX_ITEMS_PER_GROUP..-1)
        group.rss_feed_items.where(id: ids).delete_all
      end
    end
  end
end
