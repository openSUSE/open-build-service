class WatchedProject < ActiveRecord::Base
  belongs_to :user, foreign_key: 'bs_user_id'
  belongs_to :project

  validates :project_id, presence: true
  validates :bs_user_id, presence: true
 
end
