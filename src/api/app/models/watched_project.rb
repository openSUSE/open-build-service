# TODO: why not use habtm?
class WatchedProject < ActiveRecord::Base
  belongs_to :user, inverse_of: :watched_projects
  belongs_to :project, inverse_of: :watched_projects

  validates :project_id, presence: true
  validates :bs_user_id, presence: true
 
end
