# frozen_string_literal: true

class AttribDefaultValue < ApplicationRecord
  belongs_to :attrib_type
  acts_as_list scope: :attrib_type
end

# == Schema Information
#
# Table name: attrib_default_values
#
#  id             :integer          not null, primary key
#  attrib_type_id :integer          not null, indexed
#  value          :text(65535)      not null
#  position       :integer          not null
#
# Indexes
#
#  attrib_type_id  (attrib_type_id)
#
# Foreign Keys
#
#  attrib_default_values_ibfk_1  (attrib_type_id => attrib_types.id)
#
