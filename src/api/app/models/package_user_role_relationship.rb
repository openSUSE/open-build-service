class PackageUserRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :user, :foreign_key => "bs_user_id"
  belongs_to :role

  attr_accessible :db_package, :user, :role

  validates :role, :db_package, :user, :presence => true

  validate :check_duplicates, :on => :create
  def check_duplicates
    unless self.user
      errors.add(:user, "Can not assign role to nonexistent user")
    end

    if PackageUserRoleRelationship.where("db_package_id = ? AND role_id = ? AND bs_user_id = ?", self.db_package, self.role, self.user).first
      errors.add(:role, "User already has this role")
    end
  end
end
