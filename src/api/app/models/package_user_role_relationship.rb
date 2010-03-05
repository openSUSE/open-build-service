class PackageUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :user, :foreign_key => "bs_user_id"
  belongs_to :role

  def validate_on_create
    unless self.user
      errors.add "Can not assign role to nonexistent user"
    end

    if PackageUserRoleRelationship.find(:first, :conditions => ["db_package_id = ? AND role_id = ? AND bs_user_id = ?", self.db_package, self.role, self.user])
      errors.add "User already has this role"
    end
  end
end
