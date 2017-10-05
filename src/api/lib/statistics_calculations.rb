class StatisticsCalculations
  def self.get_latest_updated(limit = 10, timelimit = Time.at(0), prj_filter = ".*", pkg_filter = ".*")
    packages = Package.includes(:project).where(updated_at: timelimit..Time.now).
               where('packages.name REGEXP ? AND projects.name REGEXP ?', pkg_filter, prj_filter).
               references(:project).order("updated_at DESC").limit(limit).
               pluck(:name, "projects.name as project", :updated_at).
               map { |name, project, at| [at, :package, name, project] }

    projects = Project.where(updated_at: timelimit..Time.now).
               where('name REGEXP ?', prj_filter).
               order("updated_at DESC").limit(limit).
               pluck(:name, :updated_at).
               map { |name, at| [at, name, :project] }

    list = (packages + projects).sort { |a, b| b[0] <=> a[0] }

    limit ? list.first(limit) : list
  end
end
