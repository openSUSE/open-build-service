class NotifiedProject < ApplicationRecord
  belongs_to :notification
  belongs_to :project

  validates :notification, presence: true
  validates :project, presence: true

  validates :notification_id, uniqueness: { scope: :project_id, message: 'These notification and project are already associated' }
end
