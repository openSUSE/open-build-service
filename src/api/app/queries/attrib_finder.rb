# base class
class AttribFinder
  def initialize(relation, namespace, name)
    @relation = relation
    @namespace = namespace
    @name = name
  end

  def call
    @relation.joins(attribs: { attrib_type: :attrib_namespace })
             .where(attrib_namespaces: { name: @namespace },
                    attrib_types: { name: @name })
  end
end
