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
  scope :projects, -> { where("project_id is not null") }
  scope :packages, -> { where("package_id is not null") }
  scope :groups, -> { where("group_id is not null") }
  scope :users, -> { where("user_id is not null") }

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

  class SaveError < APIException;
  end

  def self.add_user(obj, user, role)
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
    r = obj.relationships.create(user: user, role: role)
    if r.invalid?
      logger.debug "invalid: #{r.errors.inspect}"
      r.delete
    end
  end

  def self.add_group(obj, group, role)
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

  FORBIDDEN_PROJECT_IDS_CACHE_KEY="forbidden_project_ids"

  # this is to speed up secure Project.find
  def self.forbidden_project_ids
    if User.current
      return User.current.forbidden_project_ids
    end
    # mainly for scripts
    forbidden_project_ids_for_user(nil)
  end

  def self.forbidden_project_ids_for_user(user)
    project_user_cache = Rails.cache.fetch(FORBIDDEN_PROJECT_IDS_CACHE_KEY) do
      puc = Hash.new
      Relationship.find_by_sql("SELECT ur.project_id, ur.user_id from flags f,
                relationships ur where f.flag = 'access' and f.status = 'disable' and ur.project_id = f.db_project_id").each do |r|
        puc[r.project_id] ||= Hash.new
        puc[r.project_id][r.user_id] = 1
      end
      puc
    end
    ret = [0]
    if user
      return ret if user.is_admin?
      userid = user.id
    else
      userid = User.nobodyID
    end
    project_user_cache.each do |project_id, users|
      ret << project_id unless users[userid]
    end
    # we always put a 0 in there to avoid having to check for NULL
    ret << 0 if ret.blank?
    ret
  end

  def self.discard_cache
    Rails.cache.delete(FORBIDDEN_PROJECT_IDS_CACHE_KEY)
    User.current.discard_cache if User.current
  end

  # we only care for project<->user relationships, but the cache is not *that* expensive
  # to recalculate
  after_create 'Relationship.discard_cache'
  after_rollback 'Relationship.discard_cache'
  after_destroy 'Relationship.discard_cache'

end
