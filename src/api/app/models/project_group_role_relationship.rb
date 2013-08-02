class ProjectGroupRoleRelationship < Relationship
  belongs_to :project
  belongs_to :group
  belongs_to :role

  has_many :groups_users, :through => :group

  validates :group, :presence => true
  validates :project, :presence => true
  validates :role, :presence => true

  default_scope where("relationships.project_id is not null").where("relationships.group_id is not null")

  validate :check_duplicates
  def check_duplicates
    if ProjectGroupRoleRelationship.where("project_id = ? AND role_id = ? AND group_id = ?", self.project, self.role, self.group).first
      errors.add(:group, "Group already has this role")
    end
  end
end
