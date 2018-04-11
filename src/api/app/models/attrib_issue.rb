# frozen_string_literal: true

# This class represents a issue inside of attribute part of package meta data
class AttribIssue < ApplicationRecord
  belongs_to :attrib
  belongs_to :issue
  accepts_nested_attributes_for :issue
end

# == Schema Information
#
# Table name: attrib_issues
#
#  id        :integer          not null, primary key
#  attrib_id :integer          not null, indexed => [issue_id]
#  issue_id  :integer          not null, indexed => [attrib_id], indexed
#
# Indexes
#
#  index_attrib_issues_on_attrib_id_and_issue_id  (attrib_id,issue_id) UNIQUE
#  issue_id                                       (issue_id)
#
# Foreign Keys
#
#  attrib_issues_ibfk_1  (attrib_id => attribs.id)
#  attrib_issues_ibfk_2  (issue_id => issues.id)
#
