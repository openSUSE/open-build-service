class OwnerMissingSearch < OwnerSearch
  def find
    # search in each marked project
    object_projects(nil).map do |project|
      find_containers_without_definition project, !devel_disabled?
    end.flatten
  end

  protected

  def find_containers_without_definition(rootproject, devel)
    projects = rootproject.expand_all_projects(allow_remote_projects: false)
    roles = []
    filter(rootproject).each do |f|
      roles << Role.find_by_title!(f)
    end

    # find all groups which have an active user
    maintained_groups = Group.joins(:groups_users).joins(:users).where("users.state = 'confirmed'").to_a

    # fast find packages with defintions
    # relationship in package object by user
    defined_packages = Package.where(project_id: projects).joins(relationships: :user).\
                       joins('LEFT JOIN users AS owners ON owners.id = users.owner_id').\
                       where(["relationships.role_id IN (?) AND
                              ((ISNULL(users.owner_id) AND users.state = 'confirmed') OR
                              owners.state = 'confirmed')", roles]).pluck(:name)
    # relationship in package object by group
    defined_packages += Package.where(project_id: projects).joins(:relationships).where(['relationships.role_id IN (?) AND group_id IN (?)',
                                                                                         roles, maintained_groups]).pluck(:name)
    # relationship in project object by user
    Project.joins(relationships: :user).where("projects.id in (?) AND role_id in (?) AND users.state = 'confirmed'",
                                              projects, roles).find_each do |prj|
      defined_packages += prj.packages.pluck(:name)
    end
    # relationship in project object by group
    Project.joins(:relationships).
      where('projects.id in (?) AND role_id in (?) AND group_id IN (?)', projects, roles, maintained_groups).find_each do |prj|
        defined_packages += prj.packages.pluck(:name)
      end
    # accept all incident containers in release projects. the main package (link) is enough here
    defined_packages +=
      Package.where(project_id: projects).
      joins('LEFT JOIN projects ON packages.project_id=projects.id LEFT JOIN package_kinds ON packages.id=package_kinds.package_id').
      distinct.where("projects.kind='maintenance_release' AND (ISNULL(package_kinds.kind) OR package_kinds.kind='patchinfo')").pluck(:name)

    if devel == true
      # FIXME: add devel packages, but how do recursive lookup fast in SQL?
    end
    defined_packages.uniq!

    all_packages = Package.where(project_id: projects).pluck(:name)

    undefined_packages = all_packages - defined_packages
    maintainers = []

    undefined_packages.each do |p|
      next if p =~ /\A_product:\w[-+\w\.]*\z/

      pkg = rootproject.find_package(p)

      m = Owner.new
      m.rootproject = rootproject.name
      m.project = pkg.project.name
      m.package = pkg.name

      maintainers << m
    end

    maintainers
  end
end
