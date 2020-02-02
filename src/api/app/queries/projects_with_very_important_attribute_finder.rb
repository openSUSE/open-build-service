class ProjectsWithVeryImportantAttributeFinder
  def initialize(relation = Project.all)
    @relation = relation
  end

  def call
    @relation.joins(attribs: { attrib_type: :attrib_namespace })
             .where(attrib_namespaces: { name: 'OBS' },
                    attrib_types: { name: 'VeryImportantProject' })
  end
end
