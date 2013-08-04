class Relationship < ActiveRecord::Base
  belongs_to :role

  # only one is true
  belongs_to :user
  belongs_to :group
  has_many :groups_users, through: :group
  
  belongs_to :project
  belongs_to :package

  validates :role, presence: true

  validate :check_sanity

  # don't use "is not null" - it won't be in index
  scope :projects, -> { where("project_id > 0") }
  scope :packages, -> { where("package_id > 0") }
  scope :groups, -> { where("group_id > 0") }
  scope :users, -> { where("user_id > 0") }

  protected
  def check_sanity
    if self.package_id && self.project_id
      errors.add(:package_id, "Relationships are either for project or package")
    end
    if self.group_id && self.user_id
      errors.add(:user_id, "Relationships are either for groups or users")
    end
    if !self.package_id && !self.project_id
      errors.add(:package_id, "Relationships need either a project or a package")
    end
    if !self.group_id && !self.user_id
      errors.add(:user_id, "Relationships need either a group or a user")
    end
    return unless errors.empty?
    relation=Relationship.where(role_id: self.role_id)
    if self.group_id
      relation=relation.where(group_id: self.group_id)
    else
      relation=relation.where(user_id: self.user_id)
    end
    if self.project_id
      relation=relation.where(project_id: self.project_id)
    else
      relation=relation.where(package_id: self.package_id)
    end
    if self.id
      relation = relation.where("id <> #{self.id}")
    end
    if relation.exists?
      errors.add(:role, "Relationship already exists")
    end
  end

  class SaveError < APIException; end

  def self.add_user( obj, user, role )
    obj.check_write_access!

    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role.title}' for user '#{user}' in #{obj.class} '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.get_by_login(user)
    end

    logger.debug "adding user: #{user.login}, #{role.title}"
    r = obj.relationships.create( user: user, role: role)
    if r.invalid?
      logger.debug "invalid: #{r.errors.inspect}"
      r.delete
    end
  end

  def self.add_group( obj, group, role )
    obj.check_write_access!

    unless role.kind_of? Role
      role = Role.get_by_title(role)
    end

    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in #{obj.class} '#{self.name}'"
    end

    unless group.kind_of? Group
      group = Group.find_by_title(group.to_s)
    end

    r = obj.relationships.create(group: group, role: role)
    r.delete if r.invalid?
  end

end
