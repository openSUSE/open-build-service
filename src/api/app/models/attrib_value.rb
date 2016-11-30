# This class represents a value inside of attribute part of package meta data
class AttribValue < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  acts_as_list scope: :attrib
  after_initialize :init

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :attrib

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def init
    self.value ||= get_default_value
  end

  def to_s
    value
  end

  private

  # This defines the default for AttribValue.value to ""...
  def get_default_value
    value = ""
    self.position = 1 if read_attribute(:position).blank?
    if attrib
      default = attrib.attrib_type.default_values.find_by position: position
      value = default.value if default
    end
    value
  end

  #### Alias of methods
end
