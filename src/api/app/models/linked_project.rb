class LinkedProject < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :linked_db_project, :class_name => "DbProject", :foreign_key => "linked_db_project_id"

  validate :validate_duplicates

  attr_accessible :db_project, :linked_db_project, :position, :linked_remote_project_name

  protected
  def validate_duplicates
    if not self.db_project
      errors.add(:db_project, "Can not link project to not existing project")
    elsif not self.linked_db_project and not self.linked_remote_project_name
      errors.add(:linked_db_project, "It must be linked to somewhere")
    elsif self.linked_db_project and self.linked_remote_project_name
      errors.add(:linked_remote_project_name, "Can't have a local and a remote link")
    elsif LinkedProject.where("db_project_id = ? AND linked_db_project_id = ?", self.db_project, self.linked_db_project).first
      errors.add(:db_project, "Already linked with that project")
    end
  end
end
