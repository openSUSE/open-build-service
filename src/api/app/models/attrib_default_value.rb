class AttribDefaultValue < ApplicationRecord
  belongs_to :attrib_type, optional: true
  acts_as_list scope: :attrib_type

  validates :attrib_type, presence: true
  validates :position, presence: true
  validate :value, length: { maximum: 65535 }
end

# == Schema Information
#
# Table name: attrib_default_values
#
#  id             :integer          not null, primary key
#  position       :integer          not null
#  value          :text(65535)      not null
#  attrib_type_id :integer          not null, indexed
#
# Indexes
#
#  attrib_type_id  (attrib_type_id)
#
# Foreign Keys
#
#  attrib_default_values_ibfk_1  (attrib_type_id => attrib_types.id)
#
