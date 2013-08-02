class PackageUserRoleRelationship < Relationship
  belongs_to :package
  belongs_to :user
  belongs_to :role

  validates :role, :package, :user, presence: true

  default_scope where("relationships.package_id is not null").where("relationships.user_id is not null")

  validate :check_duplicates, :on => :create
  def check_duplicates
    unless self.user
      errors.add(:user, "Can not assign role to nonexistent user")
    end

    if PackageUserRoleRelationship.where("package_id = ? AND role_id = ? AND user_id = ?", self.package_id, self.role_id, self.user_id).exists?
      errors.add(:role, "User already has this role")
    end
  end
end
