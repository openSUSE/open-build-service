# TODO: Please overwrite this comment with something explaining the model target
class LabelTemplateGlobal < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_many :label_globals, dependent: :destroy

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, length: { maximum: 255 }, presence: true
  validates :color, length: { maximum: 7 }, presence: true, format: { with: /\A#[0-9a-f]{6}\z/i, message: 'in valid hex format (#FFFFFF)' }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  # Random color from 0x000000 - 0xffffff
  def set_random_color
    self.color = "##{(rand * 0xffffff).to_i.to_s(16).rjust(6, '0')}"
  end

  #### Alias of methods
  alias_method :labels, :label_globals
end

# == Schema Information
#
# Table name: label_template_globals
#
#  id         :bigint           not null, primary key
#  color      :string(255)      not null
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
