class PackageGroupRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :group, :foreign_key => "bs_group_id"
  belongs_to :role

  def validate_on_create
    unless self.group
      errors.add "Can not assign role to nonexistent group"
    end

    if PackageGroupRoleRelationship.find(:first, :conditions => ["db_package_id = ? AND role_id = ? AND bs_group_id = ?", self.db_package, self.role, self.group])
      errors.add "Group already has this role"
    end
  end
end
