module Watchable
  extend ActiveSupport::Concern

  included do
    has_many :watched_items, as: :watchable, dependent: :destroy
    has_many :users, through: :watched_items
  end
end
