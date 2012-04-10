class AttribDefaultValue < ActiveRecord::Base
  belongs_to :attrib_type

  attr_accessible :value, :position
end
