class StatisticsCalculations
  def self.get_latest_updated(limit = 10, timelimit = nil, prj_filter = nil, pkg_filter = nil)
    list = packages(limit, timelimit, prj_filter, pkg_filter) + projects(limit, timelimit, prj_filter)

    list.sort! { |a, b| b[0] <=> a[0] }

    limit ? list.first(limit) : list
  end

  def self.packages(limit, timelimit, prj_filter, pkg_filter)
    packages = Package.includes(:project)
    packages = packages.where(updated_at: timelimit..Time.now) if timelimit
    packages = packages.where('packages.name REGEXP ?', pkg_filter) if pkg_filter
    packages = packages.where('projects.name REGEXP ?', prj_filter) if prj_filter
    packages.references(:project)
            .order('updated_at DESC')
            .limit(limit)
            .pluck(:name, 'projects.name as project', :updated_at)
            .map! { |name, project, at| [at, :package, name, project] }
  end
  private_class_method :packages

  def self.projects(limit, timelimit, prj_filter)
    projects = Project.all
    projects = projects.where(updated_at: timelimit..Time.now) if timelimit
    projects = projects.where('name REGEXP ?', prj_filter) if prj_filter
    projects.order('updated_at DESC')
            .limit(limit)
            .pluck(:name, :updated_at)
            .map! { |name, at| [at, name, :project] }
  end
  private_class_method :projects
end
