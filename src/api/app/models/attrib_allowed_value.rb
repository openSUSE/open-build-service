class AttribAllowedValue < ApplicationRecord
  belongs_to :attrib_type
end

# == Schema Information
#
# Table name: attrib_allowed_values
#
#  id             :integer          not null, primary key
#  attrib_type_id :integer          not null
#  value          :text(65535)
#
# Indexes
#
#  attrib_type_id  (attrib_type_id)
#
