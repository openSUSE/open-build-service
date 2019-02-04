class WatchItem < ApplicationRecord
  belongs_to :user
  belongs_to :item, polymorphic: true

  validates :user, :item, presence: { message: 'must be given' }
  validates :user, uniqueness: { scope: [:user_id, :item_id, :item_type] }
end
