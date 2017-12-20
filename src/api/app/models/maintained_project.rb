class MaintainedProject < ApplicationRecord
  belongs_to :project, foreign_key: :project_id
  belongs_to :maintenance_project, class_name: 'Project', foreign_key: :maintenance_project_id
end

# == Schema Information
#
# Table name: maintained_projects
#
#  id                     :integer          not null, primary key
#  project_id             :integer          not null, indexed => [maintenance_project_id]
#  maintenance_project_id :integer          not null, indexed, indexed => [project_id]
#
# Indexes
#
#  maintenance_project_id  (maintenance_project_id)
#  uniq_index              (project_id,maintenance_project_id) UNIQUE
#
# Foreign Keys
#
#  maintained_projects_ibfk_1  (project_id => projects.id)
#  maintained_projects_ibfk_2  (maintenance_project_id => projects.id)
#
