class Relationship < ActiveRecord::Base
  belongs_to :role

  # only one is true
  belongs_to :user, inverse_of: :relationships
  belongs_to :group, inverse_of: :relationships
  has_many :groups_users, through: :group

  belongs_to :project, inverse_of: :relationships
  belongs_to :package, inverse_of: :relationships

  validates :role, presence: true

  validate :check_global_role

  validates_uniqueness_of :project_id, {
    scope: [:role_id, :group_id, :user_id], allow_nil: true,
    message: "Project has non unique id"
  }
  validates_uniqueness_of :package_id, {
    scope: [:role_id, :group_id, :user_id], allow_nil: true,
    message: "Package has non unique id"
  }

  validates :package, presence: {
    message: "Neither package nor project exists"
  }, unless: 'project.present?'
  validates :package, absence: {
    message: "Package and project can not exist at the same time"
  }, if: 'project.present?'

  validates :user, presence: {
    message: "Neither user nor group exists"
  }, unless: 'group.present?'
  validates :user, absence: {
    message: "User and group can not exist at the same time"
  }, if: 'group.present?'

  def check_global_role
    return unless self.role && self.role.global
    errors.add(:base,
               "global role #{self.role.title} is not allowed.")
  end

  # don't use "is not null" - it won't be in index
  scope :projects, -> { where("project_id is not null") }
  scope :packages, -> { where("package_id is not null") }
  scope :groups, -> { where("group_id is not null") }
  scope :users, -> { where("user_id is not null") }

  class SaveError < APIException;
  end

  def self.add_user(obj, user, role, ignoreLock=nil, check=nil)
    obj.check_write_access!(ignoreLock)
    unless role.kind_of? Role
      role = Role.find_by_title!(role)
    end
    if role.global
      #only nonglobal roles may be set in an object
      raise SaveError, "tried to set global role '#{role.title}' for user '#{user}' in #{obj.class} '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.find_by_login!(user)
    end

    if obj.relationships.where(user: user, role: role).exists?
      raise SaveError, "Relationship already exists" if check
      logger.debug "ignore user #{user.login} - already has role #{role.title}"
      return
    end

    logger.debug "adding user: #{user.login}, #{role.title}"
    r = obj.relationships.build(user: user, role: role)
    if r.invalid?
      logger.debug "invalid: #{r.errors.inspect}"
      r.delete
    end
  end

  def self.add_group(obj, group, role, ignoreLock=nil, check=nil)
    obj.check_write_access!(ignoreLock)

    unless role.kind_of? Role
      role = Role.find_by_title!(role)
    end

    if role.global
      #only nonglobal roles may be set in an object
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in #{obj.class} '#{self.name}'"
    end

    unless group.kind_of? Group
      group = Group.find_by_title(group.to_s)
    end

    obj.relationships.each do |r|
      if r.group_id == group.id && r.role_id == role.id
        raise SaveError, "Relationship already exists" if check
        logger.debug "ignore group #{group.title} - already has role #{role.title}"
        return
      end
    end

    r = obj.relationships.build(group: group, role: role)
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
                relationships ur where f.flag = 'access' and f.status = 'disable' and ur.project_id = f.project_id").each do |r|
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
      userid = User.find_nobody!.id
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
