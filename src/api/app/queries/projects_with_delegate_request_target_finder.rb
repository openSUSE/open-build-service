class ProjectsWithDelegateRequestTargetFinder < AttribFinder
  def initialize(relation = Project.all, namespace = 'OBS', name = 'DelegateRequestTarget')
    super(relation, namespace, name)
  end
end
