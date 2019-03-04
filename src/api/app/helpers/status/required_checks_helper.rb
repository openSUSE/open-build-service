module Status::RequiredChecksHelper
  def build_header(project, checkable)
    case checkable
    when Repository
      { project: project.name, repository: checkable.name }
    when Package
      { project: project.name, package: checkable.name }
    when RepositoryArchitecture
      build_header(project, checkable.repository).merge(architecture: checkable.architecture.name)
    else
      { project: checkable.name }
    end
  end
end
