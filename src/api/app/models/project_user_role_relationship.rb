class ProjectUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :bs_user
  belongs_to :bs_role
end
