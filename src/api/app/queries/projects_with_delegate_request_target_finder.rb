class ProjectsWithDelegateRequestTargetFinder < AttribFinder
  def initialize(relation = Project.default_scoped, namespace = 'OBS', name = 'DelegateRequestTarget')
    super(relation, namespace, name)
  end
end
