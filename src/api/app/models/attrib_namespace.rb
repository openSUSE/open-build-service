# Specifies own namespaces of attributes
class AttribNamespace < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  has_many :attrib_types, dependent: :destroy
  has_many :attrib_namespace_modifiable_bies, class_name: 'AttribNamespaceModifiableBy', dependent: :delete_all

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  validates :name, presence: true
  validates_associated :attrib_types

  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def to_s
    name
  end

  def create_one_rule(node)
    if !node['user'] && !node['group']
      raise "attribute type '#{node.name}' modifiable_by element has no valid rules set"
    end
    new_rule = {}
    new_rule[:user] = User.find_by_login!(node['user']) if node['user']
    new_rule[:group] = Group.find_by_title!(node['group']) if node['group']
    attrib_namespace_modifiable_bies << AttribNamespaceModifiableBy.new(new_rule)
  end

  def update_from_xml(node)
    transaction do
      attrib_namespace_modifiable_bies.delete_all
      # store permission settings
      node.elements('modifiable_by') { |element| create_one_rule(element) }
      save
    end
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: attrib_namespaces
#
#  id   :integer          not null, primary key
#  name :string(255)      indexed
#
# Indexes
#
#  index_attrib_namespaces_on_name  (name)
#
