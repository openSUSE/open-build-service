# Specifies own namespaces of attributes

class AttribNamespace < ActiveRecord::Base
  has_many :attrib_types, :dependent => :destroy
  has_many :attrib_namespace_modifiable_bies, :class_name => 'AttribNamespaceModifiableBy', :dependent => :destroy

  def create_one_rule(m)
    if not m["user"] and not m["group"]
      raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
    end
    p={}
    if m["user"]
      p[:user] = User.get_by_login(m["user"])
    end
    if m["group"]
      p[:group] = Group.get_by_title(m["group"])
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

  def render_axml
    builder = Nokogiri::XML::Builder.new
    abies = attrib_namespace_modifiable_bies.includes([:user, :group])
    if abies.length > 0
      builder.namespace(:name => self.name) do |an|
         abies.each do |mod_rule|
           p={}
           p[:user] = mod_rule.user.login if mod_rule.user
           p[:group] = mod_rule.group.title if mod_rule.group
           an.modifiable_by(p)
         end
      end
    else
      builder.namespace(:name => self.name)
    end
    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
    :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
      Nokogiri::XML::Node::SaveOptions::FORMAT
  end

end
