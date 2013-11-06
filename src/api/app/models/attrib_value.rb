# This class represents a value inside of attribute part of package meta data

class AttribValue < ActiveRecord::Base
  belongs_to :attrib

  def to_s
    self.value
  end
end
