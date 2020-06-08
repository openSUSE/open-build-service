class NotifiedProject < ApplicationRecord
  belongs_to :notification
  belongs_to :project

  validates :notification, presence: true
  validates :project, presence: true

  validates :notification_id, uniqueness: { scope: :project_id, message: 'These notification and project are already associated' }
end

# == Schema Information
#
# Table name: notified_projects
#
#  id              :integer          not null, primary key
#  created_at      :datetime         not null
#  notification_id :integer          not null, indexed, indexed => [project_id]
#  project_id      :integer          not null, indexed => [notification_id]
#
# Indexes
#
#  index_notified_projects_on_notification_id                 (notification_id)
#  index_notified_projects_on_notification_id_and_project_id  (notification_id,project_id) UNIQUE
#
