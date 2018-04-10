# frozen_string_literal: true

class AttribValue < ApplicationRecord
  acts_as_list scope: :attrib
  belongs_to :attrib

  after_initialize :set_default_value

  def to_s
    value
  end

  private

  def set_default_value
    self.value = default_value if value.blank?
  end

  def default_value
    self.position = 1 if position.blank?

    if attrib
      default = attrib.attrib_type.default_values.find_by(position: position)
      default.try(:value).to_s
    else
      ''
    end
  end
end

# == Schema Information
#
# Table name: attrib_values
#
#  id        :integer          not null, primary key
#  attrib_id :integer          not null, indexed
#  value     :text(65535)      not null
#  position  :integer          not null
#
# Indexes
#
#  index_attrib_values_on_attrib_id  (attrib_id)
#
# Foreign Keys
#
#  attrib_values_ibfk_1  (attrib_id => attribs.id)
#
