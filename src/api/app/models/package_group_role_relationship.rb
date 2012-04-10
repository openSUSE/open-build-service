class PackageGroupRoleRelationship < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :group, :foreign_key => "bs_group_id"
  belongs_to :role

  has_many :groups_users, :through => :group

  validates :group, :presence => true
  validates :db_package, :presence => true
  validates :role, :presence => true

  attr_accessible :db_package, :group, :role

  validate :check_uniqueness
  protected
  def check_uniqueness
    if PackageGroupRoleRelationship.where("db_package_id = ? AND role_id = ? AND bs_group_id = ?", self.db_package, self.role, self.group).first
      errors.add(:role, "Group already has this role")
    end
  end
end
