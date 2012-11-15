class WatchedProject < ActiveRecord::Base
  belongs_to :user, foreign_key: 'bs_user_id'

  attr_accessible :name

  validates :name, presence: true
  validates :bs_user_id, presence: true
end
