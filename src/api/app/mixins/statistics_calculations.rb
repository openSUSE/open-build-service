module StatisticsCalculations
  def get_latest_updated(limit = 10)
    packages = Package.order("updated_at DESC").limit(limit).pluck(:name, :db_project_id, :updated_at).map { |name, project, at| [at, name, project] }
    projects = Project.order("updated_at DESC").limit(limit).pluck(:name, :updated_at).map { |name, at| [at, name, :project] }

    packprojs = Hash.new
    project_ids = packages.map { |x| x[2] }
    Project.where(id: project_ids.uniq).pluck(:id, :name).each do |id, name|
      packprojs[id] = name
    end
    packages.map! { |at, name, project| [at, :package, name, packprojs[project]] }

    list = packages + projects
    list.sort! { |a, b| b[0] <=> a[0] }
    list.slice(0, limit)
  end

end
