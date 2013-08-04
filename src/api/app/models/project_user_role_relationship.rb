class ProjectUserRoleRelationship < Relationship
  belongs_to :project
  belongs_to :user

  default_scope { where("relationships.project_id > 0").where("relationships.user_id > 0") }

  FORBIDDEN_PROJECT_IDS_CACHE_KEY="forbidden_project_ids"

  validate :check_duplicates, :on => :create
  def check_duplicates
    if Relationship.where("project_id = ? AND role_id = ? AND user_id = ?", self.project, self.role, self.user).exists?
      errors.add(:role, "User already has this role")
    end
  end

  # this is to speed up secure Project.find
  def self.forbidden_project_ids
    if User.current
      return User.current.forbidden_project_ids
    end
    # mainly for scripts
    forbidden_project_ids_for_user(nil)
  end

  def self.forbidden_project_ids_for_user(user)
    project_user_cache = Rails.cache.fetch(FORBIDDEN_PROJECT_IDS_CACHE_KEY) do
      puc = Hash.new
      Relationship.find_by_sql("SELECT ur.project_id, ur.user_id from flags f, 
                relationships ur where f.flag = 'access' and f.status = 'disable' and ur.project_id = f.db_project_id").each do |r|
        puc[r.project_id] ||= Hash.new
        puc[r.project_id][r.user_id] = 1
      end
      puc
    end
    ret = [0]
    if user
      return ret if user.is_admin?
      userid = user.id
    else
      userid = User.nobodyID
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
