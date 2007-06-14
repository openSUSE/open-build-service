class PackageUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :user, :foreign_key => "bs_user_id"
  belongs_to :role
end
