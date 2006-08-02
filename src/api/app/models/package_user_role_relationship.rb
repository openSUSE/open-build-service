class PackageUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :bs_user
  belongs_to :bs_role
end
