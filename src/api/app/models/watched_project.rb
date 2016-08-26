# TODO: why not use habtm?
class WatchedProject < ApplicationRecord
  belongs_to :user, inverse_of: :watched_projects
  belongs_to :project, inverse_of: :watched_projects

  validates :project, presence: true
  validates :user, presence: true
end
