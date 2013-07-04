class ProjectUserRoleRelationship < ActiveRecord::Base
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :user, foreign_key: :bs_user_id
  belongs_to :role

  attr_accessible :project, :user, :role

  FORBIDDEN_PROJECT_IDS_CACHE_KEY="forbidden_project_ids"

  validate :check_duplicates, :on => :create
  def check_duplicates
    unless self.user
      errors.add(:user, "Can not assign role to nonexistent user")
    end
    
    if ProjectUserRoleRelationship.where("db_project_id = ? AND role_id = ? AND bs_user_id = ?", self.project, self.role, self.user).first
      errors.add(:role, "User already has this role")
    end
  end

  # this is to speed up secure Project.find
  def self.forbidden_project_ids
    project_user_cache = Rails.cache.fetch(FORBIDDEN_PROJECT_IDS_CACHE_KEY) do
      puc = Hash.new
      ProjectUserRoleRelationship.find_by_sql("SELECT ur.db_project_id, ur.bs_user_id from flags f, 
                project_user_role_relationships ur where f.flag = 'access' and f.status = 'disable' and ur.db_project_id = f.db_project_id").each do |r|
        puc[r.db_project_id.to_i] ||= Hash.new
        puc[r.db_project_id][r.bs_user_id] = 1
      end
      puc
    end
    ret = []
    userid = User.nobodyID
    if User.current
      return [0] if User.current.is_admin?
      userid = User.current.id
    end
    project_user_cache.each do |project_id, users|
      ret << project_id unless users[userid]
    end
    # we always put a 0 in there to avoid having to check for NULL
    ret << 0 if ret.blank?
    ret
  end
  
  def self.discard_cache
    Rails.cache.delete(FORBIDDEN_PROJECT_IDS_CACHE_KEY)
  end

  after_create 'ProjectUserRoleRelationship.discard_cache'
  
end
