class StatisticsCalculations
  def self.get_latest_updated(limit = 10, timelimit = Time.at(0), prj_filter = '.*', pkg_filter = '.*')
    list = packages(limit, timelimit, prj_filter, pkg_filter) + projects(limit, timelimit, prj_filter)

    list.sort! { |a, b| b[0] <=> a[0] }

    limit ? list.first(limit) : list
  end

  def self.packages(limit, timelimit, prj_filter, pkg_filter)
    Package.includes(:project).where(updated_at: timelimit..Time.now).
      where('packages.name REGEXP ? AND projects.name REGEXP ?', pkg_filter, prj_filter).
      references(:project).
      order('updated_at DESC').
      limit(limit).
      pluck(:name, 'projects.name as project', :updated_at).
      map { |name, project, at| [at, :package, name, project] }
  end
  private_class_method :packages

  def self.projects(limit, timelimit, prj_filter)
    Project.where(updated_at: timelimit..Time.now).
      where('name REGEXP ?', prj_filter).
      order('updated_at DESC').
      limit(limit).
      pluck(:name, :updated_at).
      map { |name, at| [at, name, :project] }
  end
  private_class_method :projects
end
