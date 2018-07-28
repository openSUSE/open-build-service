class OwnerMissingSearch < OwnerSearch
  def find
    # find all groups which have an active user
    @maintained_groups = Group.joins(:groups_users).joins(:users).where(users: { state: 'confirmed' }).to_a

    owners = []
    # search in each marked project
    object_projects(nil).each do |project|
      @projects = project.expand_all_projects(allow_remote_projects: false)
      @roles = filter(project).map { |f| Role.find_by_title!(f) }

      (all_packages - defined_packages).each do |p|
        pkg = project.find_package(p)

        owner = Owner.new
        owner.rootproject = project.name
        owner.project = pkg.project.name
        owner.package = pkg.name
        owners << owner
      end
    end
    owners
  end

  protected

  def packages_with_confirmed_user
    Package.where(project_id: @projects).joins(relationships: :user).\
      joins('LEFT JOIN users AS owners ON owners.id = users.owner_id').\
      where(["relationships.role_id IN (?) AND
                              ((ISNULL(users.owner_id) AND users.state = 'confirmed') OR
                              owners.state = 'confirmed')", @roles]).pluck(:name)
  end

  def packages_with_maintained_group
    Package.where(project_id: @projects).joins(:relationships).where(relationships: { group: @maintained_groups, role: @roles }).pluck(:name)
  end

  def packages_with_maintainer_user_in_project
    ret = []
    Project.where(id: @projects).joins(relationships: :user).where(relationships: { role: @roles, users: { state: 'confirmed' } }).find_each do |prj|
      ret += prj.packages.pluck(:name)
    end
    ret
  end

  def packages_with_maintainer_group_in_project
    ret = []
    Project.joins(:relationships).
      where('projects.id in (?) AND role_id in (?) AND group_id IN (?)', @projects, @roles, @maintained_groups).find_each do |prj|
        ret += prj.packages.pluck(:name)
      end
    ret
  end

  # the main package (link) is enough here
  def incident_containers_in_released_projects
    Package.where(project_id: @projects).
      joins('LEFT JOIN projects ON packages.project_id=projects.id LEFT JOIN package_kinds ON packages.id=package_kinds.package_id').
      distinct.where("projects.kind='maintenance_release' AND (ISNULL(package_kinds.kind) OR package_kinds.kind='patchinfo')").pluck(:name)
  end

  def defined_packages
    defined_packages = packages_with_confirmed_user + packages_with_maintained_group
    defined_packages += packages_with_maintainer_user_in_project
    defined_packages += packages_with_maintainer_group_in_project
    defined_packages += incident_containers_in_released_projects

    # FIXME: add devel packages, but how do recursive lookup fast in SQL?
    # !devel_disabled?

    defined_packages.uniq
  end

  def all_packages
    ret = Package.where(project_id: @projects).pluck(:name)
    ret.reject { |p| p =~ /\A_product:\w[-+\w\.]*\z/ }
  end
end
