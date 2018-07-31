module OwnerSearch
  class Owned < Base
    # FIXME: add devel packages, but how do recursive lookup fast in SQL?
    def for(owner)
      @maintainers = []
      # search in each marked project
      projects_to_look_at.map do |project|
        @roles = filter(project).map { |f| Role.find_by_title!(f) }
        @projects = project.expand_all_projects(allow_remote_projects: false)
        find_projects(project, owner)
        find_packages(project, owner)
      end
      @maintainers
    end

    def filter_owner(relation, owner)
      case owner
      when User
        relation.where(user_id: owner)
      when Group
        relation.where(group_id: owner)
      else
        raise ArgumentError, "illegal object #{owner.class} handed to find_containers"
      end
    end

    def find_packages(rootproject, owner)
      found_packages = Relationship.where(role_id: @roles, package: Package.where(project_id: @projects))
      found_packages = filter_owner(found_packages, owner)
      Package.where(id: found_packages.select(:package_id)).find_each do |pkg|
        @maintainers << Owner.new(rootproject: rootproject.name, project: pkg.project.name, package: pkg.name)
      end
    end

    def find_projects(rootproject, owner)
      found_projects = Relationship.where(role_id: @roles, project: @projects)
      found_projects = filter_owner(found_projects, owner)
      Project.where(id: found_projects.select(:project_id)).pluck(:name).each do |prj|
        @maintainers << Owner.new(rootproject: rootproject.name, project: prj)
      end
    end
  end
end
