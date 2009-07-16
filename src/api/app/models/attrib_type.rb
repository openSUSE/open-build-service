class AttribType < ActiveRecord::Base
  belongs_to :db_project

  has_many :attribs
  belongs_to :attrib_namespace
end
