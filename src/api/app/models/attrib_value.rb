class AttribValue < ActiveRecord::Base
  acts_as_list :scope => :attrib
  belongs_to :attrib
end
