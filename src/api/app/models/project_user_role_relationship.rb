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

  # this is to speed up secure DbProject.find
  def self.forbidden_project_ids
       hash = Hash.new
       ProjectUserRoleRelationship.find_by_sql("SELECT ur.db_project_id, ur.bs_user_id from flags f, 
                project_user_role_relationships ur where f.flag = 'access' and ur.db_project_id = f.db_project_id").each do |r|
	       hash[r.db_project_id.to_i] ||= Hash.new
	       hash[r.db_project_id][r.bs_user_id] = 1
       end
       ret = Array.new
       userid = User.current ? User.currentID : User.nobodyID
       hash.each do |project_id, users|
	       ret << project_id unless users[userid]
       end
       ret
  end
end
