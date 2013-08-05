# Attribute definition as part of project meta data
# This is always inside of an attribute namespace

class AttribType < ActiveRecord::Base
  belongs_to :attrib_namespace

  has_many :attribs, :dependent => :destroy
  has_many :default_values, :class_name => 'AttribDefaultValue', :dependent => :destroy
  has_many :allowed_values, :class_name => 'AttribAllowedValue', :dependent => :destroy
  has_many :attrib_type_modifiable_bies, :class_name => 'AttribTypeModifiableBy', :dependent => :destroy

  class << self
    def find_by_name(name)
      name_parts = name.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{name}' must be in the $NAMESPACE:$NAME style"
      end
      find_by_namespace_and_name(name_parts[0], name_parts[1])
    end
  
    def find_by_namespace_and_name(namespace, name)
      unless namespace and name
        raise ArgumentError, "Need namespace and name as parameters"
      end
      joins(:attrib_namespace).where("attrib_namespaces.name = ? and attrib_types.name = ?", namespace, name).first
    end
  end

  def namespace
    read_attribute :attrib_namespace
  end
 
  def namespace=(val)
    write_attribute :attrib_namespace, val
  end

  def update_from_xml(node)
    self.transaction do
      #
      # defined permissions
      #
      self.attrib_type_modifiable_bies.delete_all
      # store permission setting
      node.elements.each("modifiable_by") do |m|
          if not m.attributes["user"] and not m.attributes["group"] and not m.attributes["role"]
            raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
          end
          p={}
          if m.attributes["user"]
            p[:user] = User.get_by_login(m.attributes["user"])
          end
          if m.attributes["group"]
            p[:group] = Group.get_by_title(m.attributes["group"])
          end
          if m.attributes["role"]
            p[:role] = Role.get_by_title(m.attributes["role"])
          end
          self.attrib_type_modifiable_bies << AttribTypeModifiableBy.new(p)
      end

      #
      # attribute type definition
      #
      # set value counter (this number of values must exist, not more, not less)
      self.value_count = nil
      node.elements.each("count") do |c|
        self.value_count = c.text
      end

      # allow issues?
      self.issue_list = !node.elements.find("issue_list").nil?

      # default values of a attribute stored
      self.default_values.delete_all
      position = 1
      node.elements.each("default") do |d|
        d.elements.each("value") do |v|
          self.default_values << AttribDefaultValue.new(:value => v.text, :position => position)
          position += 1
        end
      end

      # list of allowed values
      self.allowed_values.delete_all
      node.elements.each("allowed") do |a|
        a.elements.each("value") do |v|
          self.allowed_values << AttribAllowedValue.new(:value => v.text)
        end
      end

      self.save
    end
  end
end
