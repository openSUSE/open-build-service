class BsUser < User 
  has_many :watched_projects
  has_many :project_user_role_relationships
end

