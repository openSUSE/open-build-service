class WatchedItem < ApplicationRecord
    belongs_to :watchable, polymorphic: true
end
