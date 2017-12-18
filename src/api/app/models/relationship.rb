class Relationship < ApplicationRecord
  class SaveError < APIException; end

  belongs_to :role

  # only one is true
  belongs_to :user, inverse_of: :relationships
  belongs_to :group, inverse_of: :relationships
  has_many :groups_users, through: :group

  belongs_to :project, inverse_of: :relationships
  belongs_to :package, inverse_of: :relationships

  validates :role, presence: true

  validate :check_global_role

  validates :project_id, uniqueness: {
    scope: [:role_id, :group_id, :user_id], allow_nil: true,
    message: 'Project has non unique id'
  }
  validates :package_id, uniqueness: {
    scope: [:role_id, :group_id, :user_id], allow_nil: true,
    message: 'Package has non unique id'
  }

  validates :package, presence: {
    message: 'Neither package nor project exists'
  }, unless: proc { |relationship| relationship.project.present? }
  validates :package, absence: {
    message: 'Package and project can not exist at the same time'
  }, if: proc { |relationship| relationship.project.present? }

  validates :user, presence: {
    message: 'Neither user nor group exists'
  }, unless: proc { |relationship| relationship.group.present? }
  validates :user, absence: {
    message: 'User and group can not exist at the same time'
  }, if: proc { |relationship| relationship.group.present? }

  # don't use "is not null" - it won't be in index
  scope :projects, -> { where.not(project_id: nil) }
  scope :packages, -> { where.not(package_id: nil) }
  scope :groups, -> { where.not(group_id: nil) }
  scope :users, -> { where.not(user_id: nil) }
  scope :with_users_and_roles_query, lambda {
    joins(:role, :user).order('roles.title, users.login')
  }
  scope :with_groups_and_roles_query, lambda {
    joins(:role, :group).order('roles.title, groups.title')
  }
  scope :maintainers, lambda {
    where(role_id: Role.hashed['maintainer'])
  }

  # we only care for project<->user relationships, but the cache is not *that* expensive
  # to recalculate
  after_create :discard_cache
  after_rollback :discard_cache
  after_destroy :discard_cache

  def self.add_user(obj, user, role, ignore_lock = nil, check = nil)
    obj.check_write_access!(ignore_lock)
    role = Role.find_by_title!(role) unless role.is_a? Role
    if role.global
      # only nonglobal roles may be set in an object
      raise SaveError, "tried to set global role '#{role.title}' for user '#{user}' in #{obj.class} '#{name}'"
    end

    user = User.find_by_login!(user) unless user.is_a? User

    if obj.relationships.where(user: user, role: role).exists?
      raise SaveError, 'Relationship already exists' if check
      logger.debug "ignore user #{user.login} - already has role #{role.title}"
      return
    end

    logger.debug "adding user: #{user.login}, #{role.title}"
    r = obj.relationships.build(user: user, role: role)
    return unless r.invalid?
    logger.debug "invalid: #{r.errors.inspect}"
    r.delete
  end

  def self.add_group(obj, group, role, ignore_lock = nil, check = nil)
    obj.check_write_access!(ignore_lock)

    role = Role.find_by_title!(role) unless role.is_a? Role

    if role.global
      # only nonglobal roles may be set in an object
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in #{obj.class} '#{name}'"
    end

    group = Group.find_by_title(group.to_s) unless group.is_a? Group

    obj.relationships.each do |r|
      if r.group_id == group.id && r.role_id == role.id
        raise SaveError, 'Relationship already exists' if check
        logger.debug "ignore group #{group.title} - already has role #{role.title}"
        return
      end
    end

    r = obj.relationships.build(group: group, role: role)
    r.delete if r.invalid?
  end

  # calculate and cache forbidden_project_ids for users
  def self.forbidden_project_ids
    # Admins don't have forbidden projects
    return [0] if User.current && User.current.is_admin?

    # This will cache and return a hash like this:
    # {projecs: [p1,p2], whitelist: { u1: [p1], u2: [p1,p2], u3: [p2] } }
    forbidden_projects = Rails.cache.fetch('forbidden_projects') do
      forbidden_projects_hash = { projects: [], whitelist: {} }
      Relationship.find_by_sql("SELECT ur.project_id, ur.user_id from flags f,
                relationships ur where f.flag = 'access' and f.status = 'disable' and ur.project_id = f.project_id").each do |r|
        forbidden_projects_hash[:projects] << r.project_id
        if r.user_id
          forbidden_projects_hash[:whitelist][r.user_id] ||= []
          forbidden_projects_hash[:whitelist][r.user_id] << r.project_id if r.user_id
        end
      end
      forbidden_projects_hash[:projects].uniq!
      forbidden_projects_hash[:projects] << 0 if forbidden_projects_hash[:projects].empty?

      forbidden_projects_hash
    end
    # We don't need to check the relationships if we don't have a User
    return forbidden_projects[:projects] if User.current.nil? || User.current.is_nobody?
    # The cache sequence is for invalidating user centric cache entries for all users
    cache_sequence = Rails.cache.read('cache_sequence_for_forbidden_projects') || 0
    Rails.cache.fetch("users/#{User.current.id}-forbidden_projects-#{cache_sequence}") do
      # Normal users can be in the whitelist let's substract allowed projects
      whitelistened_projects_for_user = forbidden_projects[:whitelist][User.current.id] || []
      result = forbidden_projects[:projects] - whitelistened_projects_for_user
      result = [0] if result.empty?
      result
    end
  end

  def self.discard_cache
    # Increasing the cache sequence will 'discard' all user centric forbidden_projects caches
    cache_sequence = Rails.cache.read('cache_sequence_for_forbidden_projects') || 0
    Rails.cache.write('cache_sequence_for_forbidden_projects', cache_sequence + 1)
    Rails.cache.delete('forbidden_projects')
  end

  def self.with_users_and_roles
    with_users_and_roles_query.pluck('users.login as login, roles.title AS role_name')
  end

  def self.with_groups_and_roles
    with_groups_and_roles_query.pluck('groups.title as title', 'roles.title as role_name')
  end

  private

  def discard_cache
    Relationship.discard_cache
  end

  def check_global_role
    return unless role && role.global
    errors.add(:base,
               "global role #{role.title} is not allowed.")
  end
end

# == Schema Information
#
# Table name: relationships
#
#  id         :integer          not null, primary key
#  package_id :integer          indexed => [role_id, group_id], indexed => [role_id, user_id]
#  project_id :integer          indexed => [role_id, group_id], indexed => [role_id, user_id]
#  role_id    :integer          not null, indexed => [package_id, group_id], indexed => [package_id, user_id], indexed => [project_id, group_id], indexed => [project_id, user_id], indexed
#  user_id    :integer          indexed => [package_id, role_id], indexed => [project_id, role_id], indexed
#  group_id   :integer          indexed, indexed => [package_id, role_id], indexed => [project_id, role_id]
#
# Indexes
#
#  group_id                                                    (group_id)
#  index_relationships_on_package_id_and_role_id_and_group_id  (package_id,role_id,group_id) UNIQUE
#  index_relationships_on_package_id_and_role_id_and_user_id   (package_id,role_id,user_id) UNIQUE
#  index_relationships_on_project_id_and_role_id_and_group_id  (project_id,role_id,group_id) UNIQUE
#  index_relationships_on_project_id_and_role_id_and_user_id   (project_id,role_id,user_id) UNIQUE
#  role_id                                                     (role_id)
#  user_id                                                     (user_id)
#
# Foreign Keys
#
#  relationships_ibfk_1  (role_id => roles.id)
#  relationships_ibfk_2  (user_id => users.id)
#  relationships_ibfk_3  (group_id => groups.id)
#  relationships_ibfk_4  (project_id => projects.id)
#  relationships_ibfk_5  (package_id => packages.id)
#
