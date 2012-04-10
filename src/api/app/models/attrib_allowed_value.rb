class AttribAllowedValue < ActiveRecord::Base
  belongs_to :attrib_type

  attr_accessible :value
end
