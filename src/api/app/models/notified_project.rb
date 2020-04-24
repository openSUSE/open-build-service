class NotifiedProject < ApplicationRecord
  belongs_to :notification
  belongs_to :project

  validates :notification, presence: true
  validates :project, presence: true
end
