class OBSQualityCategoriesFinder
  def self.call(project)
    AttribValue
      .joins(attrib: { attrib_type: :attrib_namespace })
      .where(attribs: { project: project },
             attrib_types: { name: 'QualityCategory' },
             attrib_namespaces: { name: 'OBS' })
      .map(&:value)
  end
end
