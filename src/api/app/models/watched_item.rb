class WatchedItem < ApplicationRecord
  belongs_to :watchable, polymorphic: true
  belongs_to :user

  validates :watchable_id, uniqueness: { scope: [:watchable_type, :user_id] }
end

# == Schema Information
#
# Table name: watched_items
#
#  id             :integer          not null, primary key
#  watchable_type :string(255)      not null, indexed => [watchable_id, user_id], indexed => [watchable_id]
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer          indexed => [watchable_type, watchable_id], indexed
#  watchable_id   :integer          not null, indexed => [watchable_type, user_id], indexed => [watchable_type]
#
# Indexes
#
#  index_watched_items_on_type_id_and_user_id  (watchable_type,watchable_id,user_id) UNIQUE
#  index_watched_items_on_user_id              (user_id)
#  index_watched_items_on_watchable            (watchable_type,watchable_id)
#
