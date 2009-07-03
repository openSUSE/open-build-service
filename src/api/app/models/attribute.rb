class Attribute < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :attrib_type
  has_many :attrib_value, :dependent => :destroy
end
