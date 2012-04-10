# This class represents a value inside of attribute part of package meta data

class AttribValue < ActiveRecord::Base
  belongs_to :attrib

  attr_accessible :value, :position 
end
