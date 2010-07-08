class LinkedProject < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :linked_db_project, :class_name => "DbProject", :foreign_key => "linked_db_project_id"

  def validate_on_create
    if not self.db_project
      errors.add "Can not link project to not existing project"
    elsif not self.linked_db_project
      errors.add "It must be linked to somewhere"
    elsif LinkedProject.find(:first, :conditions => ["db_project_id = ? AND linked_db_project_id = ?", self.db_project, self.linked_db_project])
      errors.add "Already linked with that project"
    end
  end
end
