class LinkedProject < ApplicationRecord
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :linked_db_project, :class_name => "Project", foreign_key: :linked_db_project_id

  validate :validate_duplicates

  protected

  def validate_duplicates
    if not self.project
      errors.add(:project, "Can not link project to not existing project")
    elsif !self.linked_db_project && !self.linked_remote_project_name
      errors.add(:linked_db_project, "It must be linked to somewhere")
    elsif self.linked_db_project && self.linked_remote_project_name
      errors.add(:linked_remote_project_name, "Can't have a local and a remote link")
    elsif LinkedProject.where("db_project_id = ? AND linked_db_project_id = ?", self.project, self.linked_db_project).first
      errors.add(:project, "Already linked with that project")
    end
  end
end
