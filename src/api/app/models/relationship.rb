class Relationship < ApplicationRecord
  belongs_to :role

  # only one is true
  belongs_to :user, inverse_of: :relationships, optional: true
  belongs_to :group, inverse_of: :relationships, optional: true
  has_many :groups_users, through: :group

  belongs_to :project, inverse_of: :relationships, optional: true
  belongs_to :package, inverse_of: :relationships, optional: true

  validate :check_global_role

  validates :project_id, uniqueness: {
    scope: %i[role_id group_id user_id], allow_nil: true,
    message: 'Project has non unique id'
  }
  validates :package_id, uniqueness: {
    scope: %i[role_id group_id user_id], allow_nil: true,
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

  validate :allowed_user

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
    where(role: Role.hashed['maintainer'])
  }
  # FIXME: This probably can be refactored to avoid instantiation inside the `map`
  scope :user_with_maintainer_role, lambda {
    where(role: Role.hashed['maintainer'])
      .map { |relation| relation.user || relation.group.users }
      .flatten.uniq
  }
  scope :for_package, ->(package) { where(package: package) }
  scope :for_project, ->(project) { where(project: project) }

  scope :bugowners, lambda {
    where(role: Role.hashed['bugowner'])
  }

  scope :bugowners_with_email, lambda {
    bugowners.joins(:user).merge(User.with_email)
  }

  after_create :create_relationship_create_event

  # we only care for project<->user relationships, but the cache is not *that* expensive
  # to recalculate
  after_create :discard_cache
  after_destroy :discard_cache
  after_rollback :discard_cache

  RELATIONSHIP_CACHE_SEQUENCE = 'cache_sequence_for_forbidden_projects'.freeze

  def self.add_user(obj, user, role, ignore_lock = nil, check = nil)
    add_role(obj, role, user: user, ignore_lock: ignore_lock, check: check)
  end

  def self.add_group(obj, group, role, ignore_lock = nil, check = nil)
    add_role(obj, role, group: group, ignore_lock: ignore_lock, check: check)
  end

  # calculate and cache forbidden_project_ids for users
  def self.forbidden_project_ids
    # Admins don't have forbidden projects
    return [0] if User.admin_session?

    # This will cache and return a hash like this:
    # {projecs: [p1,p2], whitelist: { u1: [p1], u2: [p1,p2], u3: [p2] } }
    forbidden_projects = Rails.cache.fetch('forbidden_projects') do
      forbidden_projects_hash = { projects: [], whitelist: {} }
      RelationshipsFinder.new.disabled_projects.each do |r|
        forbidden_projects_hash[:projects] << r.project_id
        user_id = r.user_id || r.groups_user_id
        if user_id
          forbidden_projects_hash[:whitelist][user_id] ||= []
          forbidden_projects_hash[:whitelist][user_id] << r.project_id
        end
      end
      forbidden_projects_hash[:projects].uniq!
      forbidden_projects_hash[:projects] << 0 if forbidden_projects_hash[:projects].empty?

      forbidden_projects_hash
    end
    # We don't need to check the relationships if we don't have a User
    return forbidden_projects[:projects] unless User.session

    # The cache sequence is for invalidating user centric cache entries for all users
    Rails.cache.fetch(cache_user_centric_key) do
      # Normal users can be in the whitelist let's substract allowed projects
      whitelistened_projects_for_user = forbidden_projects[:whitelist][User.possibly_nobody.id] || []
      result = forbidden_projects[:projects] - whitelistened_projects_for_user
      result = [0] if result.empty?
      result
    end
  end

  def self.discard_cache
    # Increasing the cache sequence will 'discard' all user centric forbidden_projects caches
    Rails.cache.write(RELATIONSHIP_CACHE_SEQUENCE, cache_sequence + 1)
    Rails.cache.delete('forbidden_projects')
  end

  def self.with_users_and_roles
    with_users_and_roles_query.pluck(:login, :title)
  end

  def self.with_groups_and_roles
    with_groups_and_roles_query.pluck('groups.title', 'roles.title')
  end

  def create_relationship_delete_event
    return unless User.session

    Event::RelationshipDelete.create(event_parameters)
  end

  private

  class << self
    def add_role(obj, role, opts = {})
      Relationship::AddRole.new(obj, role, opts).add_role
    end

    def cache_sequence
      Rails.cache.fetch(RELATIONSHIP_CACHE_SEQUENCE) { 0 }
    end

    def cache_user_centric_key
      "users/#{User.possibly_nobody.id}-forbidden_projects-#{cache_sequence}"
    end
  end

  def discard_cache
    Relationship.discard_cache
  end

  def check_global_role
    return unless role && role.global

    errors.add(:base,
               "global role #{role.title} is not allowed.")
  end

  # NOTE: Adding a normal validation, the error doesn't reach the view due to
  # Relationship::AddRole#add_role handling.
  # We could also check other banned users, not only nobody.
  def allowed_user
    raise NotFoundError, "Couldn't find user #{user.login}" if user && user.nobody?
  end

  def create_relationship_create_event
    return unless User.session

    Event::RelationshipCreate.create(event_parameters)
  end

  def event_parameters
    parameters = { who: User.session.login,
                   user: user&.login,
                   group: group&.title,
                   role: role.title,
                   notifiable_id: id }
    if package
      parameters[:project] = package.project.name
      parameters[:package] = package.name
    else
      parameters[:project] = project.name
    end

    parameters
  end
end

# == Schema Information
#
# Table name: relationships
#
#  id         :integer          not null, primary key
#  group_id   :integer          indexed, indexed => [package_id, role_id], indexed => [project_id, role_id]
#  package_id :integer          indexed => [role_id, group_id], indexed => [role_id, user_id]
#  project_id :integer          indexed => [role_id, group_id], indexed => [role_id, user_id]
#  role_id    :integer          not null, indexed => [package_id, group_id], indexed => [package_id, user_id], indexed => [project_id, group_id], indexed => [project_id, user_id], indexed
#  user_id    :integer          indexed => [package_id, role_id], indexed => [project_id, role_id], indexed
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
