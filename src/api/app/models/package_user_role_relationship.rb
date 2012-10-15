class PackageUserRoleRelationship < ActiveRecord::Base
  belongs_to :package, foreign_key: :db_package_id
  belongs_to :user, :foreign_key => :bs_user_id
  belongs_to :role

  attr_accessible :package, :user, :role

  validates :role, :package, :user, presence: true

  validate :check_duplicates, :on => :create
  def check_duplicates
    unless self.user
      errors.add(:user, "Can not assign role to nonexistent user")
    end

    if PackageUserRoleRelationship.where("db_package_id = ? AND role_id = ? AND bs_user_id = ?", self.db_package_id, self.role_id, self.bs_user_id).first
      errors.add(:role, "User already has this role")
    end
  end
end
