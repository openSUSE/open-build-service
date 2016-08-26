# This class represents a issue inside of attribute part of package meta data
class AttribIssue < ApplicationRecord
  belongs_to :attrib
  belongs_to :issue
  accepts_nested_attributes_for :issue
end
