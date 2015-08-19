class AttribDefaultValue < ActiveRecord::Base
  belongs_to :attrib_type
  acts_as_list scope: :attrib_type
end
