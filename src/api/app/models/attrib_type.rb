# Attribute definition as part of project meta data
# This is always inside of an attribute namespace

class AttribType < ActiveRecord::Base
  belongs_to :attrib_namespace

  has_many :attribs, dependent: :destroy
  has_many :default_values, -> { order("position ASC") }, :class_name => 'AttribDefaultValue', dependent: :delete_all
  has_many :allowed_values, :class_name => 'AttribAllowedValue', dependent: :delete_all
  has_many :attrib_type_modifiable_bies, :class_name => 'AttribTypeModifiableBy', dependent: :delete_all

  validates :name, presence: true

  class << self
    class UnknownAttributeTypeError < APIException
      setup 'unknown_attribute_type', 404, 'Unknown Attribute Type'
    end

    def find_by_name!(name)
       find_by_name(name, true)
    end

    def find_by_name(name, or_fail=false)
      name_parts = name.split(/:/)
      if name_parts.length != 2
        raise ArgumentError, "attribute '#{name}' must be in the $NAMESPACE:$NAME style"
      end
      find_by_namespace_and_name(name_parts[0], name_parts[1], or_fail)
    end

    def find_by_namespace_and_name!(namespace, name)
       find_by_namespace_and_name(namespace, name, true)
    end

    def find_by_namespace_and_name(namespace, name, or_fail=false)
      unless namespace and name
        raise ArgumentError, "Need namespace and name as parameters"
      end
      ats = joins(:attrib_namespace).where("attrib_namespaces.name = ? and attrib_types.name = ?", namespace, name)
      if or_fail and ats.count != 1
        raise UnknownAttributeTypeError, "Attribute Type #{namespace}:#{name} does not exist"
      end
      ats.first
    end
  end

  def namespace
    self.attrib_namespace.name
  end

  def fullname
    return "#{self.attrib_namespace}:#{self.name}"
  end

  def create_one_rule(m)
    if m["user"].blank? and m["group"].blank? and m["role"].blank?
      raise RuntimeError, "attribute type '#{node.name}' modifiable_by element has no valid rules set"
    end
    p={}
    if m["user"]
      p[:user] = User.find_by_login!(m["user"])
    end
    if m["group"]
      p[:group] = Group.find_by_title!(m["group"])
    end
    if m["role"]
      p[:role] = Role.find_by_title!(m["role"])
    end
    self.attrib_type_modifiable_bies << AttribTypeModifiableBy.new(p)
  end

  def update_default_values(default_elements)
    self.default_values.delete_all
    position = 1
    default_elements.each do |d|
      d.elements("value") do |v|
        self.default_values << AttribDefaultValue.new(value: v, position: position)
        position += 1
      end
    end
  end

  def update_from_xml(xmlhash)
    self.transaction do
      #
      # defined permissions
      #
      self.attrib_type_modifiable_bies.delete_all

      # store permission setting
      xmlhash.elements("modifiable_by") { |m| create_one_rule(m) }

      #
      # attribute type definition
      #
      self.description = nil
      xmlhash.elements("description") do |c|
        self.description = c
      end

      # set value counter (this number of values must exist, not more, not less)
      self.value_count = nil
      xmlhash.elements("count") do |c|
        self.value_count = c
      end

      # allow issues?
      logger.debug "XML #{xmlhash.inspect}"
      self.issue_list = !xmlhash["issue_list"].nil?
      logger.debug "IL #{self.issue_list}"

      # default values of a attribute stored
      self.update_default_values(xmlhash.elements("default"))

      # list of allowed values
      self.allowed_values.delete_all
      xmlhash.elements("allowed") do |a|
        a.elements("value") do |v|
          self.allowed_values << AttribAllowedValue.new(:value => v)
        end
      end

      self.save
    end
  end

  # FIXME: we REALLY should use active_model_serializers
  def as_json(options = nil)
    if options
      if options.key?(:methods)
        if options[:methods].kind_of? Array
          options[:methods] << :attrib_namespace_name unless options[:methods].include?(:attrib_namespace_name)
        elsif options[:methods] != :attrib_namespace_name
          options[:methods] = [options[:methods]] + [:attrib_namespace_name]
        end
      else
        options[:methods] = [:attrib_namespace_name]
      end
      super(options)
    else
      super(methods: [:attrib_namespace_name])
    end
  end
end
