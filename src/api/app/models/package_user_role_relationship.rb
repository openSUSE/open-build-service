class PackageUserRoleRelationship < Relationship
  belongs_to :package
  belongs_to :user

  default_scope where("relationships.package_id > 0").where("relationships.user_id > 0")

  validate :check_duplicates, :on => :create
  def check_duplicates
    if Relationship.where("package_id = ? AND role_id = ? AND user_id = ?", self.package_id, self.role_id, self.user_id).exists?
      errors.add(:role, "User already has this role")
    end
  end
end
