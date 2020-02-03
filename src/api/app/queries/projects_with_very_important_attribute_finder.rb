class ProjectsWithVeryImportantAttributeFinder < AttribFinder
  def initialize(relation = Project.all, namespace = 'OBS', name = 'VeryImportantProject')
    super(relation, namespace, name)
  end
end
