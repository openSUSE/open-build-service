module ProjectDistribution
  # Check if the project has a path_element matching project and repository
  def distribution?(project_name, repository)
    local_distribution?(project_name, repository) || remote_distribution?(project_name, repository)
  end

  def remote_distribution?(project_name, repository)
    linked_repositories.remote.any? do |linked_repository|
      project_name.end_with?(linked_repository.remote_project_name) && linked_repository.name == repository
    end
  end

  def local_distribution?(project_name, repository)
    linked_repositories.not_remote.any? do |linked_repository|
      linked_repository.project.name == project_name &&
        linked_repository.name == repository
    end
  end
end
