class ProjectUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :user, :foreign_key => 'bs_user_id'
  belongs_to :bs_role
end
