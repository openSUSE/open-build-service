# returns all projects with attribute 'OBS:ImageTemplates'
class ProjectsWithImageTemplatesFinder < AttribFinder
  def initialize(relation = Project.default_scoped, namespace = 'OBS', name = 'ImageTemplates')
    super
  end
end
