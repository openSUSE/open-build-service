class ProjectsWithImageTemplatesFinder < AttribFinder
  def initialize(relation = Project.all, namespace = 'OBS', name = 'ImageTemplates')
    super(relation, namespace, name)
  end
end
