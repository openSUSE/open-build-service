# This class represents a issue inside of attribute part of package meta data

class AttribIssue < ActiveRecord::Base
  belongs_to :attrib
  belongs_to :issue
end
