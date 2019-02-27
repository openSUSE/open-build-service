module Status::RequiredChecksHelper
  def build_header(project, checkable)
    if checkable.is_a?(Repository)
      { project: project.name, repository: checkable.name }
    elsif checkable.is_a?(Package)
      { project: project.name, package: checkable.name }
    elsif checkable.is_a?(RepositoryArchitecture)
      build_header(project, checkable.repository).merge(architecture: checkable.architecture.name)
    else
      { project: checkable.name }
    end
  end
end
