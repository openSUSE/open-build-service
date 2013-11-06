# Specifies own namespaces of attributes

class AttribNamespace < ActiveRecord::Base
  has_many :attrib_types, dependent: :destroy
  has_many :attrib_namespace_modifiable_bies, :class_name => 'AttribNamespaceModifiableBy', dependent: :delete_all

  def to_s
    self.name 
  end

  def create_one_rule(m)
    if not m["user"] and not m["group"]
      raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
    end
    p={}
    if m["user"]
      p[:user] = User.find_by_login!(m["user"])
    end
    if m["group"]
      p[:group] = Group.find_by_title!(m["group"])
    end
    self.attrib_namespace_modifiable_bies << AttribNamespaceModifiableBy.new(p)
  end

  def update_from_xml(node)
    self.transaction do
      self.attrib_namespace_modifiable_bies.delete_all
      # store permission settings
      node.elements("modifiable_by") { |m| create_one_rule(m) }
      self.save
    end
  end

end
