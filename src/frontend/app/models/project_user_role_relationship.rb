class ProjectUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :user, :foreign_key => 'bs_user_id'
  belongs_to :role

  def validate_on_create
    unless self.user
      errors.add "Can not assign role to nonexistent user"
    end

    if ProjectUserRoleRelationship.find(:first, :conditions => ["db_project_id = ? AND role_id = ? AND bs_user_id = ?", self.db_project, self.role, self.user])
      errors.add "User already has this role"
    end
  end
end
