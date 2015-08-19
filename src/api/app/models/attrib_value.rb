# This class represents a value inside of attribute part of package meta data

class AttribValue < ActiveRecord::Base
  belongs_to :attrib
  acts_as_list scope: :attrib
  after_initialize :init

  def init
    if self.value.nil?
      self.value = get_default_value
    end
  end

  def to_s
    self.value
  end

  private
  def get_default_value
    # This defines the default for AttribValue.value to ""...
    value = ""
    if read_attribute(:position).blank?
      self.position = 1
    end
    if self.attrib
      default = self.attrib.attrib_type.default_values.find_by position: self.position
      if default
        value = default.value
      end
    end
    return value
  end
end
