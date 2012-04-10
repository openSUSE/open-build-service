class ProjectGroupRoleRelationship < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :group, :foreign_key => 'bs_group_id'
  belongs_to :role

  has_many :groups_users, :through => :group

  validates :group, :presence => true
  validates :db_project, :presence => true
  validates :role, :presence => true

  attr_accessible :db_project, :group, :role

  validate :check_duplicates
  def check_duplicates
    if ProjectGroupRoleRelationship.where("db_project_id = ? AND role_id = ? AND bs_group_id = ?", self.db_project, self.role, self.group).first
      errors.add(:group, "Group already has this role")
    end
  end
end
