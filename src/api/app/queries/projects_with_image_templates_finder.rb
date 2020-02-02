class ProjectsWithImageTemplatesFinder
  def initialize(relation = Project.all)
    @relation = relation
  end

  def call
    @relation.includes(:packages).joins(attribs: { attrib_type: :attrib_namespace })
             .where(attrib_types: { name: 'ImageTemplates' },
                    attrib_namespaces: { name: 'OBS' })
             .order(:title)
  end
end
