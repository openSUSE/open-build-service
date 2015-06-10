module StatisticsCalculations
  def get_latest_updated(limit = 10, timelimit = Time.at(0))
    packages = Package.includes(:project).where(updated_at: timelimit..Time.now).order("updated_at DESC").limit(limit).pluck(:name, "projects.name as project", :updated_at).map { |name, project, at| [at, :package, name, project] }
    projects = Project.where(updated_at: timelimit..Time.now).order("updated_at DESC").limit(limit).pluck(:name, :updated_at).map { |name, at| [at, name, :project] }

    list = packages + projects
    list.sort! { |a, b| b[0] <=> a[0] }
    return list if limit.nil?
    list.slice(0, limit)
  end
end

