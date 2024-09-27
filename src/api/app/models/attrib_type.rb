# Attribute definition as part of project meta data. This is always inside of an attribute namespace
class AttribType < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  class UnknownAttributeTypeError < APIError
    setup 'unknown_attribute_type', 404, 'Unknown Attribute Type'
  end

  class InvalidAttributeError < APIError
  end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :attrib_namespace

  has_many :attribs, dependent: :destroy
  has_many :default_values, -> { order('position ASC') }, class_name: 'AttribDefaultValue', dependent: :delete_all
  has_many :allowed_values, class_name: 'AttribAllowedValue', dependent: :delete_all
  has_many :attrib_type_modifiable_bies, class_name: 'AttribTypeModifiableBy', dependent: :delete_all

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  validates :name, presence: true

  #### Class methods using self. (public and then private)
  def self.find_by_name!(name)
    find_by_name(name, or_fail: true)
  end

  def self.find_by_name(name, or_fail: false)
    name_parts = name.split(':')
    raise InvalidAttributeError, "Attribute '#{name}' must be in the $NAMESPACE:$NAME style" if name_parts.length != 2

    find_by_namespace_and_name(name_parts[0], name_parts[1], or_fail: or_fail)
  end

  def self.find_by_namespace_and_name!(namespace, name)
    find_by_namespace_and_name(namespace, name, or_fail: true)
  end

  def self.find_by_namespace_and_name(namespace, name, or_fail: false)
    raise ArgumentError, 'Need namespace and name as parameters' unless namespace && name

    attribute_type = joins(:attrib_namespace).find_by('attrib_namespaces.name = ? and attrib_types.name = ?', namespace, name)
    raise UnknownAttributeTypeError, "Attribute Type #{namespace}:#{name} does not exist" if or_fail && attribute_type.blank?

    attribute_type
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def namespace
    attrib_namespace.name
  end

  def fullname
    "#{attrib_namespace}:#{name}"
  end

  def update_from_xml(xmlhash)
    transaction do
      # defined permissions
      attrib_type_modifiable_bies.delete_all

      # store permission setting
      xmlhash.elements('modifiable_by') { |element| create_one_rule(element) }

      # attribute type definition
      self.description = nil
      xmlhash.elements('description') do |element|
        self.description = element
      end

      # set value counter (this number of values must exist, not more, not less)
      self.value_count = nil
      xmlhash.elements('count') do |element|
        self.value_count = element
      end

      # allow issues?
      logger.debug "XML #{xmlhash.inspect}"
      self.issue_list = !xmlhash['issue_list'].nil?
      logger.debug "IL #{issue_list}"

      # default values of a attribute stored
      update_default_values(xmlhash.elements('default'))

      # list of allowed values
      allowed_values.delete_all
      xmlhash.elements('allowed') do |allowed_element|
        allowed_element.elements('value') do |value_element|
          allowed_values.build(value: value_element)
        end
      end

      save
    end
  end

  # FIXME: we REALLY should use active_model_serializers
  def as_json(options = nil)
    if options
      if options.key?(:methods)
        if options[:methods].is_a?(Array)
          options[:methods] << :attrib_namespace_name unless options[:methods].include?(:attrib_namespace_name)
        elsif options[:methods] != :attrib_namespace_name
          options[:methods] = [options[:methods]] + [:attrib_namespace_name]
        end
      else
        options[:methods] = [:attrib_namespace_name]
      end
      super
    else
      super(methods: [:attrib_namespace_name])
    end
  end

  private

  def create_one_rule(node)
    raise "attribute type '#{node.name}' modifiable_by element has no valid rules set" if node['user'].blank? && node['group'].blank? && node['role'].blank?

    new_rule = {}
    new_rule[:user] = User.find_by_login!(node['user']) if node['user']
    new_rule[:group] = Group.find_by_title!(node['group']) if node['group']
    new_rule[:role] = Role.find_by_title!(node['role']) if node['role']
    attrib_type_modifiable_bies << AttribTypeModifiableBy.new(new_rule)
  end

  def update_default_values(default_elements)
    default_values.delete_all
    position = 1
    default_elements.each do |d|
      d.elements('value') do |v|
        default_values << AttribDefaultValue.new(value: v, position: position)
        position += 1
      end
    end
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: attrib_types
#
#  id                  :integer          not null, primary key
#  description         :string(255)
#  issue_list          :boolean          default(FALSE)
#  name                :string(255)      not null, indexed => [attrib_namespace_id], indexed
#  type                :string(255)
#  value_count         :integer
#  attrib_namespace_id :integer          not null, indexed => [name]
#
# Indexes
#
#  index_attrib_types_on_attrib_namespace_id_and_name  (attrib_namespace_id,name) UNIQUE
#  index_attrib_types_on_name                          (name)
#
# Foreign Keys
#
#  attrib_types_ibfk_1  (attrib_namespace_id => attrib_namespaces.id)
#
