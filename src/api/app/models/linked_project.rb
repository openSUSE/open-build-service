class LinkedProject < ApplicationRecord
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :linked_db_project, class_name: "Project", foreign_key: :linked_db_project_id

  validate :validate_duplicates

  protected

  def validate_duplicates
    if !project
      errors.add(:project, "Can not link project to not existing project")
    elsif !linked_db_project && !linked_remote_project_name
      errors.add(:linked_db_project, "It must be linked to somewhere")
    elsif linked_db_project && linked_remote_project_name
      errors.add(:linked_remote_project_name, "Can't have a local and a remote link")
    elsif LinkedProject.find_by(project: project, linked_db_project: linked_db_project)
      errors.add(:project, "Already linked with that project")
    end
  end
end
