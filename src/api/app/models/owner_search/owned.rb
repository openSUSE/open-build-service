module OwnerSearch
  class Owned < Base
    def for(owner)
      @maintainers = []
      # search in each marked project
      projects_to_look_at.map do |project|
        @roles = filter(project).map { |f| Role.find_by_title!(f) }
        @projects = project.expand_all_projects(allow_remote_projects: false)
        find_containers(project, owner)
      end
      @maintainers
    end

    def find_containers(rootproject, owner)
      found_packages = Relationship.where(role_id: @roles, package_id: Package.where(project_id: @projects).pluck(:id))
      found_projects = Relationship.where(role_id: @roles, project_id: @projects)
      # fast find packages with defintions
      case owner
      when User
        # user in package object
        found_packages = found_packages.where(user_id: owner)
        # user in project object
        found_projects = found_projects.where(user_id: owner)
      when Group
        # group in package object
        found_packages = found_packages.where(group_id: owner)
        # group in project object
        found_projects = found_projects.where(group_id: owner)
      else
        raise ArgumentError, "illegal object #{owner.class} handed to find_containers"
      end
      unless devel_disabled?(rootproject)
        # FIXME: add devel packages, but how do recursive lookup fast in SQL?
      end
      found_packages = found_packages.pluck(:package_id).uniq
      found_projects = found_projects.pluck(:project_id).uniq

      Project.where(id: found_projects).pluck(:name).each do |prj|
        @maintainers << Owner.new(rootproject: rootproject.name, project: prj)
      end
      Package.where(id: found_packages).find_each do |pkg|
        @maintainers << Owner.new(rootproject: rootproject.name, project: pkg.project.name, package: pkg.name)
      end
    end
  end
end
