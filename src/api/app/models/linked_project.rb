class LinkedProject < ApplicationRecord
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :linked_db_project, class_name: 'Project', foreign_key: :linked_db_project_id

  validate :validate_duplicates

  protected

  def validate_duplicates
    if !project
      errors.add(:project, 'Can not link project to not existing project')
    elsif !linked_db_project && !linked_remote_project_name
      errors.add(:linked_db_project, 'It must be linked to somewhere')
    elsif linked_db_project && linked_remote_project_name
      errors.add(:linked_remote_project_name, "Can't have a local and a remote link")
    elsif LinkedProject.find_by(project: project, linked_db_project: linked_db_project)
      errors.add(:project, 'Already linked with that project')
    end
  end
end

# == Schema Information
#
# Table name: linked_projects
#
#  id                         :integer          not null, primary key
#  db_project_id              :integer          not null, indexed => [linked_db_project_id]
#  linked_db_project_id       :integer          indexed => [db_project_id]
#  position                   :integer
#  linked_remote_project_name :string(255)
#  vrevmode                   :string(10)       default("standard")
#
# Indexes
#
#  linked_projects_index  (db_project_id,linked_db_project_id) UNIQUE
#
