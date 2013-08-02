class PackageGroupRoleRelationship < Relationship
  belongs_to :package
  belongs_to :group
  belongs_to :role

  has_many :groups_users, through: :group

  validates :group, presence: true
  validates :package, presence: true
  validates :role, presence: true

  validate :check_uniqueness

  default_scope where("relationships.package_id is not null").where("relationships.group_id is not null")

  protected
  def check_uniqueness
    if PackageGroupRoleRelationship.where("package_id = ? AND role_id = ? AND group_id = ?", self.package, self.role, self.group).first
      errors.add(:role, "Group already has this role")
    end
  end
end
