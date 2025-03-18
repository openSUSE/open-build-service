class AttribValue < ApplicationRecord
  acts_as_list scope: :attrib
  belongs_to :attrib, optional: true

  after_initialize :set_default_value
  before_validation :universal_newlines

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

  def universal_newlines
    self.value = value.encode(universal_newline: true)
  end
end

# == Schema Information
#
# Table name: attrib_values
#
#  id        :integer          not null, primary key
#  position  :integer          not null
#  value     :text(65535)      not null
#  attrib_id :integer          not null, indexed
#
# Indexes
#
#  index_attrib_values_on_attrib_id  (attrib_id)
#
# Foreign Keys
#
#  fk_rails_...  (attrib_id => attribs.id) ON DELETE => cascade
#
