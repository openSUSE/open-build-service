# Attribute definition as part of project meta data
# This is always inside of an attribute namespace

class AttribType < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :attrib_namespace

  has_many :attribs, :dependent => :destroy
  has_many :default_values, :class_name => 'AttribDefaultValue', :dependent => :delete_all
  has_many :allowed_values, :class_name => 'AttribAllowedValue', :dependent => :delete_all
  has_many :attrib_type_modifiable_by, :class_name => 'AttribTypeModifiableBy', :dependent => :destroy

  def self.inheritance_column
    "bla"
  end

  class << self
    def find_by_name(name)
      name_parts = name.split /:/
      if name_parts.length != 2
        raise RuntimeError, "attribute '#{name}' must be in the $NAMESPACE:$NAME style"
      end
      find_by_namespace_and_name(name_parts[0], name_parts[1])
    end

    def find_by_namespace_and_name(namespace, name)
      unless namespace and name
        raise RuntimeError, "attribute must be in the $NAMESPACE:$NAME style" 
      end
      find :first, :joins => "JOIN attrib_namespaces an ON attrib_types.attrib_namespace_id = an.id", :conditions => ["attrib_types.name = BINARY ? and an.name = BINARY ?", name, namespace]
    end
  end

  def namespace
    read_attribute :attrib_namespace
  end
 
  def namespace=(val)
    write_attribute :attrib_namespace, val
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))
     p = {}
     p[:name]      = self.name
     p[:namespace] = attrib_namespace.name
     node.definition(p) do |attr|

       if default_values.length > 0
         attr.default do |default|
           default_values.each do |def_val|
             default.value def_val.value
           end
         end
       end

       if allowed_values.length > 0
         attr.allowed do |allowed|
           allowed_values.each do |all_val|
             allowed.value all_val.value
           end
         end
       end

       if self.value_count
         attr.count self.value_count
       end

       if attrib_type_modifiable_by.length > 0
         attrib_type_modifiable_by.each do |mod_rule|
           p={}
           p[:user] = mod_rule.user.login if mod_rule.user 
           p[:group] = mod_rule.group.title if mod_rule.group 
           p[:role] = mod_rule.role.title if mod_rule.role 
           attr.modifiable_by(p)
         end
       end

     end
  end

  def update_from_xml(node)
    #
    # permission handling
    #
    # working without cache, first remove aller permissions
    self.attrib_type_modifiable_by.delete_all
    # store permission settings
    if node.has_element? :modifiable_by
      node.each_modifiable_by do |m|
        if not m.has_attribute? :user and not m.has_attribute? :group and not m.has_attribute? :role
          raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set" 
        end
        p={}
        if m.has_attribute? :user
          p[:user] = User.find_by_login(m.user)
          raise RuntimeError, "Unknown user '#{m.user}' in modifiable_by element" if not p[:user]
        end
        if m.has_attribute? :group
          p[:group] = Group.find_by_title(m.group)
          raise RuntimeError, "Unknown group '#{m.group}' in modifiable_by element" if not p[:group]
        end
        if m.has_attribute? :role
          p[:role] = Role.find_by_title(m.role)
          raise RuntimeError, "Unknown role '#{m.role}' in modifiable_by element" if not p[:role]
        end
        self.attrib_type_modifiable_by << AttribTypeModifiableBy.new(p)
      end
    end

    #
    # attribute type definition
    #
    # set value counter (this number of values must exist, not more, not less)
    if node.has_element? :count
      self.value_count = node.count.to_s
    else
      self.value_count = nil
    end

    # default values of a attribute stored
    if node.has_element? :default
      logger.debug "--- updating attrib default definition content ---"

      update_values = false
      update_values = true unless node.default.each_value.length == self.default_values.count

      node.default.each_value.each_with_index do |val, i|
        next if val.to_s == self.default_values[i].value
        update_values = true
        break
      end unless update_values

      if update_values
        logger.debug "--- updating values ---"
        self.default_values.delete_all
        node.default.each_value do |val|
          self.default_values << AttribDefaultValue.new(:value => val.to_s)
        end
      end
    else
      self.default_values.delete_all
    end

    # list of allowed values
    if node.has_element? :allowed
      logger.debug "--- updating attrib allowed definition content ---"
      update_values = false
      update_values = true unless node.allowed.each_value.length == self.allowed_values.count

      node.allowed.each_value.each_with_index do |val, i|
        next if val.to_s == self.allowed_values[i].value
        update_values = true
        break
      end unless update_values

      if update_values
        logger.debug "--- updating values ---"
        self.allowed_values.delete_all
        node.allowed.each_value do |val|
          self.allowed_values << AttribAllowedValue.new(:value => val.to_s)
        end
      end
    else
      self.allowed_values.delete_all
    end

    self.save
  end
end
