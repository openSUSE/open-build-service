class ProjectGroupRoleRelationship < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :group, :foreign_key => 'bs_group_id'
  belongs_to :role

  validate :check_duplicates, :on => :create

  def check_duplicates
    unless self.group
      errors.add "Can not assign role to nonexistent group"
    end

    if ProjectGroupRoleRelationship.find(:first, :conditions => ["db_project_id = ? AND role_id = ? AND bs_group_id = ?", self.db_project, self.role, self.group])
      errors.add "Group already has this role"
    end
  end
end
