class Relationship::AddRole
  class SaveError < APIError; end

  def initialize(package_or_project, role, opts)
    self.package_or_project = package_or_project
    self.role = role
    self.check = opts[:check]

    package_or_project.check_write_access!(opts[:ignore_lock])
    check_role!
    check_add_role_arguments!(opts)
  end

  def add_role
    return if duplicate?

    relationship = package_or_project.relationships.build(user: user, group: group, role: role)
    relationship.delete if relationship.invalid?
  end

  private

  attr_accessor :package_or_project, :role, :user, :group, :check

  def duplicate?
    return unless package_or_project.relationships.exists?(user: user, group: group, role: role)
    raise SaveError, 'Relationship already exists' if check

    true
  end

  def check_add_role_arguments!(opts)
    raise ArgumentError, 'need either user or group' unless opts[:user].present? ^ opts[:group].present?

    self.user = opts[:user]
    self.user = User.find_by_login!(user) if user.is_a?(String)

    self.group = opts[:group]
    self.group = Group.find_by_title!(group) if group.is_a?(String)
  end

  def check_role!
    self.role = Role.find_by_title!(role) unless role.is_a?(Role)
    return unless role.global

    # only nonglobal roles may be set in an object
    raise SaveError, "tried to set global role '#{role.title}' in #{package_or_project.class} '#{package_or_project.name}'"
  end
end
