# TODO: why not use habtm?
class WatchedProject < ActiveRecord::Base
  belongs_to :user, foreign_key: 'bs_user_id', inverse_of: :watched_projects
  belongs_to :project, inverse_of: :watched_projects

  validates :project_id, presence: true
  validates :bs_user_id, presence: true
 
end
